import re
from datetime import date, datetime
from typing import List, Tuple, Optional
from urllib.parse import urlparse

from schemas import ExtractedProductClaims, ProductCategory, AuditCheckItem


# ==========================================
# 1. GS1 MODULO-10 CHECKSUM ALGORITHM
# ==========================================
def validate_gtin_checksum(barcode: Optional[str]) -> Tuple[bool, str, bool]:
    """
    Validates GS1 GTIN-8, GTIN-12 (UPC), GTIN-13 (EAN-13), or GTIN-14.
    Returns: (is_valid, message, is_applicable)
    """
    if not barcode:
        return True, "No barcode provided for checksum validation.", False

    digits_only = re.sub(r"\D", "", barcode)
    
    # If the barcode is not standard GTIN length, it is likely an internal/Code-128 serial barcode.
    # Do NOT hard fail products with non-GTIN serial barcodes.
    if len(digits_only) not in (8, 12, 13, 14):
        return True, f"Barcode '{barcode}' is a non-GTIN proprietary/serial format ({len(digits_only)} chars); checksum check skipped.", False

    check_digit = int(digits_only[-1])
    payload = digits_only[:-1]

    total_sum = 0
    multiplier = 3
    for digit in reversed(payload):
        total_sum += int(digit) * multiplier
        multiplier = 1 if multiplier == 3 else 3

    calculated_check = (10 - (total_sum % 10)) % 10

    if calculated_check == check_digit:
        return True, f"Valid GS1 Modulo-10 checksum (Check digit: {check_digit}).", True
    else:
        return False, f"Checksum mismatch: expected check digit {calculated_check}, got {check_digit}.", True


# ==========================================
# 2. BRAND SERIAL / BATCH SYNTAX PATTERNS
# ==========================================
# Verified standards:
# - Dell: 7 alphanumeric characters (Base-36)
# - Apple: 10 characters (randomized modern) or 12 characters (legacy)
# - HP: 10 to 12 alphanumeric characters
# - Lenovo: 7 to 10 alphanumeric characters
# - Sony Audio: 7 digits
SERIAL_REGEX_PATTERNS = {
    "dell": r"^[A-Z0-9]{7}$",
    "apple": r"^[A-Z0-9]{10}$|^[A-Z0-9]{12}$",
    "hp": r"^[A-Z0-9]{10,12}$",
    "lenovo": r"^[A-Z0-9]{7,10}$",
    "sony": r"^\d{7}$",
}


def validate_serial_syntax(brand: Optional[str], serial: Optional[str], category: ProductCategory) -> Tuple[bool, str, bool]:
    """
    Returns: (passed, details_message, is_definitive_hard_fail)
    """
    if not serial:
        return True, "No serial/batch number provided to validate.", False

    clean_serial = serial.strip().upper()

    # Definitive failure: Absurdly short (<3 chars) or contains illegal special symbols
    if len(clean_serial) < 3 or not re.match(r"^[A-Z0-9\-\.\/]+$", clean_serial):
        return False, f"Invalid identifier syntax '{clean_serial}': contains illegal characters or impossible length.", True

    if category == ProductCategory.MEDICINE:
        return True, f"Batch format '{clean_serial}' adheres to pharmaceutical alphanumeric standards.", False

    if not brand:
        return True, "Brand unconfirmed; syntax check passed basic alphanumeric validation.", False

    brand_key = brand.strip().lower()
    for known_brand, pattern in SERIAL_REGEX_PATTERNS.items():
        if known_brand in brand_key:
            if re.match(pattern, clean_serial):
                return True, f"Serial '{clean_serial}' matches standard {known_brand.title()} format.", False
            else:
                # Advisory warning only (is_definitive_hard_fail = False)
                # Lets Tier-3 official portal verify it rather than false-flagging a valid sub-model
                return False, f"Advisory: Serial '{clean_serial}' deviates from typical {known_brand.title()} length; deferring to Tier-3 portal lookup.", False

    return True, f"Serial '{clean_serial}' passed alphanumeric structural validation.", False

# ==========================================
# 3. EXPIRY & SHELF-LIFE ARITHMETIC
# ==========================================
def parse_date_safely(date_str: Optional[str]) -> Optional[date]:
    if not date_str:
        return None
    
    clean_str = date_str.strip()
    
    # Handle MM/YY or MM-YY (e.g., '12/26' -> '2026-12-28')
    short_year_match = re.match(r"^(\d{1,2})[\/\-](\d{2})$", clean_str)
    if short_year_match:
        m, y = int(short_year_match.group(1)), int(f"20{short_year_match.group(2)}")
        try:
            return date(y, m, 28)
        except ValueError:
            return None

    # Exact day formats
    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(clean_str, fmt).date()
        except ValueError:
            continue

    # Month-only formats -> set day to 28 so current-month products aren't flagged expired
    for fmt in ("%Y-%m", "%m/%Y", "%Y/%m"):
        try:
            parsed = datetime.strptime(clean_str, fmt).date()
            return parsed.replace(day=28)
        except ValueError:
            continue

    return None


def validate_expiry_and_shelf_life(
    expiry_str: Optional[str], mfg_str: Optional[str], category: ProductCategory
) -> List[Tuple[bool, str]]:
    checks = []
    today = date.today()

    exp_date = parse_date_safely(expiry_str)
    mfg_date = parse_date_safely(mfg_str)

    if exp_date:
        if exp_date < today:
            checks.append((False, f"EXPIRED: Product expired on {exp_date.isoformat()} (Current date: {today.isoformat()})."))
        else:
            checks.append((True, f"Unexpired: Expiry date {exp_date.isoformat()} is valid."))

    if exp_date and mfg_date:
        shelf_life_days = (exp_date - mfg_date).days
        if shelf_life_days < 0:
            checks.append((False, "Invalid timeline: Expiry date precedes Manufacturing date."))
        elif category == ProductCategory.MEDICINE and shelf_life_days > (5 * 365 + 30):
            # CDSCO / WHO limit of 5 years (60 months)
            checks.append((False, f"Anomalous shelf life ({shelf_life_days // 365} years). Exceeds statutory 5-year limit."))
        else:
            checks.append((True, "Shelf life duration is within legitimate bounds."))

    return checks


# ==========================================
# 4. INTERNAL CONSISTENCY (FOIL vs BARCODE)
# ==========================================
def validate_foil_vs_barcode_consistency(claims: ExtractedProductClaims) -> Tuple[bool, str]:
    if not claims.barcode_embedded_batch or not claims.serial_or_batch_number:
        return True, "Dual-source consistency check not applicable (no 2D barcode batch detected)."

    barcode_batch = re.sub(r"[\s\-\/]", "", claims.barcode_embedded_batch.upper())
    printed_batch = re.sub(r"[\s\-\/]", "", claims.serial_or_batch_number.upper())

    if barcode_batch == printed_batch:
        return True, f"Internal consistency confirmed: Barcode batch matches printed foil text ({claims.serial_or_batch_number})."
    else:
        return False, f"CRITICAL MISMATCH: Barcode batch ({claims.barcode_embedded_batch}) does NOT match printed packaging batch ({claims.serial_or_batch_number})."


# ==========================================
# 5. QR DOMAIN & PHISHING GUARD
# ==========================================
SUSPICIOUS_TLDS = {".xyz", ".top", ".cc", ".tk", ".cf", ".ga", ".ml", ".buzz", ".monster", ".fit"}
TRUSTED_ROOT_DOMAINS = {
    "sony.com", "apple.com", "dell.com", "lenovo.com", "hp.com", "logitech.com",
    "cdsco.gov.in", "gs1india.org", "cipla.com", "sunpharma.com", "fda.gov"
}


def validate_qr_domain(qr_url: Optional[str]) -> Tuple[bool, str, bool]:
    """
    Returns: (is_safe, message, is_hard_fail)
    """
    if not qr_url:
        return True, "No QR redirect URL present.", False

    parsed = urlparse(qr_url)
    hostname = (parsed.netloc or parsed.path).lower().split(":")[0]

    # Check for known disposable/malicious TLDs
    if any(hostname.endswith(tld) for tld in SUSPICIOUS_TLDS):
        return False, f"PHISHING ALERT: QR points to high-risk disposable TLD '{hostname}'.", True

    # Check against known manufacturer domains
    is_whitelisted = any(hostname == domain or hostname.endswith("." + domain) for domain in TRUSTED_ROOT_DOMAINS)
    if is_whitelisted:
        return True, f"QR domain '{hostname}' matches verified manufacturer whitelist.", False

    # Unknown domain: Not an immediate fake, but flagged for inspection
    return True, f"QR domain '{hostname}' is not in standard manufacturer whitelist; proceeding to Tier-3 verification.", False


# ==========================================
# MASTER TIER-2 GATEKEEPER ORCHESTRATOR
# ==========================================
def run_tier2_gatekeeper(claims: ExtractedProductClaims) -> Tuple[bool, List[AuditCheckItem]]:
    audit_items: List[AuditCheckItem] = []
    hard_fail = False

    # 1. Barcode Checksum (Definitive mathematical check)
    gtin_passed, gtin_msg, is_gtin = validate_gtin_checksum(claims.barcode_gtin)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="GS1 GTIN Modulo-10 Checksum", passed=gtin_passed, details=gtin_msg))
    if is_gtin and not gtin_passed:
        hard_fail = True

    # 2. Serial / Batch Syntax (Only hard-fails on impossible syntax; regex mismatch defers to Tier-3)
    serial_passed, serial_msg, is_serial_hard_fail = validate_serial_syntax(
        claims.brand_name, claims.serial_or_batch_number, claims.category
    )
    audit_items.append(AuditCheckItem(tier="Tier-2", name="Serial / Batch Syntax Check", passed=serial_passed, details=serial_msg))
    if is_serial_hard_fail:
        hard_fail = True

    # 3. Expiry / Shelf-Life Arithmetic (Definitive chronological check)
    date_checks = validate_expiry_and_shelf_life(claims.expiry_date, claims.mfg_date, claims.category)
    for passed, msg in date_checks:
        audit_items.append(AuditCheckItem(tier="Tier-2", name="Temporal Expiry & Shelf-Life", passed=passed, details=msg))
        if not passed:
            hard_fail = True

    # 4. Foil vs Barcode Batch Consistency (Definitive contradiction check)
    foil_passed, foil_msg = validate_foil_vs_barcode_consistency(claims)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="Foil vs Barcode Dual-Source Consistency", passed=foil_passed, details=foil_msg))
    if not foil_passed:
        hard_fail = True

    # 5. QR Phishing / Whitelist Check (Definitive TLD check)
    domain_safe, domain_msg, is_domain_hard_fail = validate_qr_domain(claims.qr_redirect_url)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="QR Security & Domain Check", passed=domain_safe, details=domain_msg))
    if is_domain_hard_fail:
        hard_fail = True

    return (not hard_fail), audit_items