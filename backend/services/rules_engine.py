import re
from datetime import date, datetime
from typing import List, Tuple, Optional
from urllib.parse import urlparse

from schemas import ExtractedProductClaims, ProductCategory, AuditCheckItem


# 1. GS1 MODULO-10 CHECKSUM ALGORITHM
def validate_gtin_checksum(gtin: Optional[str]) -> Tuple[bool, str]:
    """
    Validates GS1 GTIN-8, GTIN-12 (UPC), GTIN-13 (EAN-13), or GTIN-14.
    Algorithm:
    Starting from the digit immediately to the left of the check digit and moving backwards:
    alternately multiply digits by 3 and 1, sum them up.
    The check digit is (10 - (sum % 10)) % 10.
    """
    if not gtin:
        return True, "No GTIN barcode provided for checksum validation."

    # Clean non-digit characters
    digits_only = re.sub(r"\D", "", gtin)
    if len(digits_only) not in (8, 12, 13, 14):
        return False, f"Invalid GTIN length ({len(digits_only)} digits). Standard lengths are 8, 12, 13, or 14."

    check_digit = int(digits_only[-1])
    payload = digits_only[:-1]

    # Calculate checksum: weights alternate 3 and 1 starting from the rightmost payload digit
    total_sum = 0
    multiplier = 3
    for digit in reversed(payload):
        total_sum += int(digit) * multiplier
        multiplier = 1 if multiplier == 3 else 3

    calculated_check = (10 - (total_sum % 10)) % 10

    if calculated_check == check_digit:
        return True, f"Valid GS1 Modulo-10 checksum (Check digit: {check_digit})."
    else:
        return False, f"Checksum mismatch: expected check digit {calculated_check}, but got {check_digit}."


# 2. BRAND SERIAL / BATCH SYNTAX PATTERNS
SERIAL_REGEX_PATTERNS = {
    # Dell Service Tags: 7 alphanumeric chars, excluding I, O, Q, S, Z
    "dell": r"^[A-HJ-NP-RT-Z0-9]{7}$",
    # Apple: 10 or 12 alphanumeric characters
    "apple": r"^[A-HJ-NP-Z0-9]{10,12}$",
    # Lenovo: 8 alphanumeric characters
    "lenovo": r"^[A-Z0-9]{8}$",
    # HP: 10 alphanumeric characters
    "hp": r"^[A-Z0-9]{10}$",
    # Sony Audio: 7 numeric digits
    "sony": r"^\d{7}$",
    # Generic Pharma Batch: 4-15 alphanumeric characters with optional hyphens/slashes
    "generic_pharma": r"^[A-Za-z0-9\-\/]{4,15}$",
}


def validate_serial_syntax(brand: Optional[str], serial: Optional[str], category: ProductCategory) -> Tuple[bool, str]:
    if not serial:
        return True, "No serial/batch number provided to validate."

    clean_serial = serial.strip()

    if category == ProductCategory.MEDICINE:
        pattern = SERIAL_REGEX_PATTERNS["generic_pharma"]
        if re.match(pattern, clean_serial):
            return True, f"Batch format '{clean_serial}' matches standard pharmaceutical batch syntax."
        return False, f"Batch '{clean_serial}' violates standard batch formatting syntax."

    # Electronics path
    if not brand:
        return True, "Brand unknown; skipped strict brand serial regex."

    brand_key = brand.strip().lower()
    for known_brand, pattern in SERIAL_REGEX_PATTERNS.items():
        if known_brand in brand_key:
            if re.match(pattern, clean_serial.upper()):
                return True, f"Serial '{clean_serial}' conforms to official {known_brand.title()} formatting standards."
            else:
                return False, f"Serial '{clean_serial}' does not conform to official {known_brand.title()} syntax pattern."

    return True, f"No strict regex registered for brand '{brand}'; format permitted."


# 3. EXPIRY & SHELF-LIFE ARITHMETIC
def parse_date_safely(date_str: Optional[str]) -> Optional[date]:
    if not date_str:
        return None
    for fmt in ("%Y-%m-%d", "%Y-%m", "%d/%m/%Y", "%m/%Y"):
        try:
            return datetime.strptime(date_str.strip(), fmt).date()
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
            checks.append((False, f"EXPIRED: Product expired on {exp_date.isoformat()} (Audit date: {today.isoformat()})."))
        else:
            checks.append((True, f"Unexpired: Expiry date {exp_date.isoformat()} is valid."))

    if exp_date and mfg_date:
        shelf_life_days = (exp_date - mfg_date).days
        # If expiry is before manufacturing
        if shelf_life_days < 0:
            checks.append((False, "Invalid chronology: Expiry date precedes Manufacturing date."))
        # Anomalous shelf life check: Pharma standard max is 5 years (1825 days)
        elif category == ProductCategory.MEDICINE and shelf_life_days > (5 * 365):
            checks.append((False, f"Anomalous shelf life detected ({shelf_life_days // 365} years). Exceeds 5-year pharmaceutical limit."))
        else:
            checks.append((True, "Shelf life duration is within normal regulatory bounds."))

    return checks


# 4. INTERNAL CONSISTENCY (FOIL vs BARCODE)

def validate_foil_vs_barcode_consistency(claims: ExtractedProductClaims) -> Tuple[bool, str]:
    """
    Catches counterfeiters printing new fake batch numbers on foil
    while reusing cloned authentic 2D barcodes.
    """
    if not claims.barcode_embedded_batch or not claims.serial_or_batch_number:
        return True, "No embedded 2D barcode batch available for dual-source consistency check."

    barcode_batch = claims.barcode_embedded_batch.strip().upper()
    printed_batch = claims.serial_or_batch_number.strip().upper()

    if barcode_batch == printed_batch:
        return True, f"Internal consistency confirmed: Encoded barcode batch matches printed foil text ({printed_batch})."
    else:
        return False, f"CRITICAL MISMATCH: Encoded barcode batch ({barcode_batch}) does NOT match printed packaging batch ({printed_batch})."


# 5. QR DOMAIN WHITELIST & PHISHING CHECK
TRUSTED_DOMAINS = {
    # Electronics
    "sony.com", "apple.com", "dell.com", "lenovo.com", "hp.com", "logitech.com",
    # Pharma & Regulatory
    "cdsco.gov.in", "gs1india.org", "cipla.com", "sunpharma.com", "fda.gov", "who.int"
}

SUSPICIOUS_TLDS = {".xyz", ".top", ".cc", ".tk", ".cf", ".ga", ".ml", ".buzz", ".monster"}


def validate_qr_domain(qr_url: Optional[str]) -> Tuple[bool, str]:
    if not qr_url:
        return True, "No QR redirect URL present."

    parsed = urlparse(qr_url)
    hostname = (parsed.netloc or parsed.path).lower().split(":")[0]

    # Check for suspicious TLDs often used in disposable counterfeit verification sites
    if any(hostname.endswith(tld) for tld in SUSPICIOUS_TLDS):
        return False, f"PHISHING ALERT: QR points to high-risk disposable domain '{hostname}'."

    # Whitelist check: Domain must end with an approved root domain
    is_trusted = any(hostname == domain or hostname.endswith("." + domain) for domain in TRUSTED_DOMAINS)
    if is_trusted:
        return True, f"QR domain '{hostname}' matches verified manufacturer/regulatory whitelist."
    else:
        return False, f"UNTRUSTED DOMAIN: '{hostname}' is not in the approved authoritative registry."


# MASTER TIER-2 GATEKEEPER ORCHESTRATOR
def run_tier2_gatekeeper(claims: ExtractedProductClaims) -> Tuple[bool, List[AuditCheckItem]]:
    """
    Runs all Tier-2 checks in <5ms.
    Returns: (passed_all_hard_checks, list_of_audit_items)
    """
    audit_items: List[AuditCheckItem] = []
    hard_fail = False

    # 1. Barcode Checksum
    gtin_passed, gtin_msg = validate_gtin_checksum(claims.barcode_gtin)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="GS1 GTIN Modulo-10 Checksum", passed=gtin_passed, details=gtin_msg))
    if not gtin_passed and claims.barcode_gtin:
        hard_fail = True

    # 2. Serial / Batch Syntax
    serial_passed, serial_msg = validate_serial_syntax(claims.brand_name, claims.serial_or_batch_number, claims.category)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="Serial / Batch Syntax Regex", passed=serial_passed, details=serial_msg))
    if not serial_passed:
        hard_fail = True

    # 3. Expiry / Shelf-Life
    date_checks = validate_expiry_and_shelf_life(claims.expiry_date, claims.mfg_date, claims.category)
    for passed, msg in date_checks:
        audit_items.append(AuditCheckItem(tier="Tier-2", name="Temporal Expiry & Shelf-Life", passed=passed, details=msg))
        if not passed:
            hard_fail = True

    # 4. Foil vs Barcode Batch Consistency
    foil_passed, foil_msg = validate_foil_vs_barcode_consistency(claims)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="Foil vs Barcode Dual-Source Consistency", passed=foil_passed, details=foil_msg))
    if not foil_passed:
        hard_fail = True

    # 5. QR Domain Whitelist
    domain_passed, domain_msg = validate_qr_domain(claims.qr_redirect_url)
    audit_items.append(AuditCheckItem(tier="Tier-2", name="QR Redirect Domain Whitelist", passed=domain_passed, details=domain_msg))
    if not domain_passed and claims.qr_redirect_url:
        hard_fail = True

    return (not hard_fail), audit_items