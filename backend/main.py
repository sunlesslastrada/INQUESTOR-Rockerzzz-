from typing import Optional, Dict, Any, List
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from schemas import (
    LogoAuditResponse,
    ExtractedProductClaims,
    ProductCategory,
    VerificationRequest,
    VerificationResponse,
    VerdictStatus,
    AuditCheckItem,
)
from services.vision_service import audit_logo_image, extract_packaging_text
from services.barcode_service import decode_optical_codes
from services.rules_engine import run_tier2_gatekeeper
from services.tinyfish_service import run_tier3_investigation

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Product Authenticity & Forensic Evidence Engine for HackIIITD",
)

# Enable CORS for Flutter Web / Mobile client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {
        "project": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "online",
        "mock_mode": settings.MOCK_MODE,
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}


# ==========================================
# TIER-0: AUTONOMOUS LOGO AUDIT
# ==========================================
@app.post(
    f"{settings.API_V1_PREFIX}/verify-logo",
    response_model=LogoAuditResponse,
    tags=["Tier-0 Logo Audit"],
)
async def verify_logo(file: UploadFile = File(...)):
    """
    Accepts cropped logo/emblem image.
    Uses Gemini Vision to identify brand, detect category, and spot visual spoofing.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Invalid file type. Please upload an image file (PNG/JPEG/WEBP).",
        )

    contents = await file.read()
    return await audit_logo_image(contents)


# ==========================================
# TIER-1: MULTI-MODAL INTAKE
# ==========================================
@app.post(
    f"{settings.API_V1_PREFIX}/extract",
    response_model=ExtractedProductClaims,
    tags=["Tier-1 Intake"],
)
async def extract_product_data(
    category: ProductCategory = Form(ProductCategory.ELECTRONICS),
    packaging_image: UploadFile = File(..., description="Crop containing packaging text/foil"),
    barcode_image: UploadFile = File(..., description="Crop containing 1D barcode or 2D DataMatrix"),
    qr_image: Optional[UploadFile] = File(None, description="Optional separate QR code image"),
):
    """
    Decodes barcode/DataMatrix via pyzbar and extracts natural text via Gemini Vision.
    Returns normalized claims for Human-in-the-Loop review.
    """
    pkg_bytes = await packaging_image.read()
    barcode_bytes = await barcode_image.read()

    barcode_data = decode_optical_codes(barcode_bytes)

    qr_url = barcode_data.get("qr_redirect_url")
    if qr_image:
        qr_bytes = await qr_image.read()
        qr_data = decode_optical_codes(qr_bytes)
        if qr_data.get("qr_redirect_url"):
            qr_url = qr_data["qr_redirect_url"]

    text_data = await extract_packaging_text(pkg_bytes, category)

    serial_or_batch = (
        text_data.get("serial_or_batch_number")
        or barcode_data.get("embedded_serial")
        or barcode_data.get("embedded_batch")
    )

    return ExtractedProductClaims(
        category=category,
        brand_name=text_data.get("brand_name"),
        model_or_drug_name=text_data.get("model_or_drug_name"),
        barcode_gtin=barcode_data.get("barcode_gtin"),
        serial_or_batch_number=serial_or_batch,
        expiry_date=text_data.get("expiry_date") or barcode_data.get("embedded_expiry"),
        mfg_date=text_data.get("mfg_date"),
        qr_redirect_url=qr_url,
        barcode_embedded_batch=barcode_data.get("embedded_batch"),
        barcode_embedded_expiry=barcode_data.get("embedded_expiry"),
    )


# ==========================================
# MASTER RECONCILIATION & AUDIT PIPELINE
# ==========================================
@app.post(
    f"{settings.API_V1_PREFIX}/verify",
    response_model=VerificationResponse,
    tags=["Forensic Verification"],
)
async def verify_product(request: VerificationRequest):
    """
    Executes Tier-2 local rules and Tier-3 authoritative web investigation.
    Returns one of three verdicts: VERIFIED MATCH, SUSPICIOUS, or UNABLE TO VERIFY.
    """
    checklist: List[AuditCheckItem] = []
    claims = request.claims

    # 1. Ingest Tier-0 Logo Summary into Master Checklist (if provided)
    if request.tier0_logo_summary:
        t0 = request.tier0_logo_summary
        t0_valid = t0.get("is_logo_valid", True)
        t0_brand = t0.get("detected_brand", "Unknown")
        t0_reason = t0.get("reasoning", "Visual brand analysis recorded.")
        checklist.append(
            AuditCheckItem(
                tier="Tier-0",
                name="Visual Brand & Emblem Audit",
                passed=t0_valid,
                details=f"Brand '{t0_brand}': {t0_reason}",
            )
        )

    # 2. Tier-2 Deterministic Fast-Fail Gatekeeper (<5ms)
    tier2_passed, tier2_items = run_tier2_gatekeeper(claims)
    checklist.extend(tier2_items)

    # If Tier-2 failed hard checks and user did NOT specify force_continue:
    if not tier2_passed and not request.force_continue:
        # Find the specific failing check to build forensic discrepancy
        failed_checks = [item for item in tier2_items if not item.passed]
        primary_fail = failed_checks[0] if failed_checks else None

        discrepancy = None
        if primary_fail:
            discrepancy = {
                "field": primary_fail.name,
                "packaging_claim": f"Input: {claims.barcode_gtin or claims.serial_or_batch_number or 'Packaging value'}",
                "official_record": primary_fail.details,
            }

        return VerificationResponse(
            verdict=VerdictStatus.SUSPICIOUS,
            category=claims.category,
            summary_banner="Counterfeit Risk Detected: Failed deterministic local physical/mathematical checks. Web investigation skipped.",
            forensic_discrepancy=discrepancy,
            checklist=checklist,
            raw_evidence={"tier2_fast_fail": True, "failed_checks": [f.details for f in failed_checks]},
        )

    # 3. Tier-3 Authoritative Investigation (TinyFish or Mock Resilience Engine)
    use_mock = settings.MOCK_MODE if request.mock_mode is None else request.mock_mode
    t3_verdict, t3_item, discrepancy, raw_evidence = await run_tier3_investigation(
        claims=claims,
        use_mock=use_mock,
        demo_preset=request.demo_preset,
    )
    checklist.append(t3_item)

    # If Tier-2 had a hard fail but user force-continued, verdict stays SUSPICIOUS
    final_verdict = VerdictStatus.SUSPICIOUS if not tier2_passed else t3_verdict

    # 4. Synthesize Informative Banner
    if final_verdict == VerdictStatus.VERIFIED_MATCH:
        banner = (
            "Information Match Confirmed. Note: Digital verification confirms packaging "
            "data matches official records, but cannot physically or chemically rule out physical packaging duplication."
        )
    elif final_verdict == VerdictStatus.SUSPICIOUS:
        banner = (
            "Counterfeit Risk Detected: Contradiction found between packaging claims and authoritative records."
        )
    else:
        banner = (
            "Unable to Verify: Packaging syntax passed deterministic checks, but no public "
            "authoritative verification registry is available for this brand."
        )

    return VerificationResponse(
        verdict=final_verdict,
        category=claims.category,
        summary_banner=banner,
        forensic_discrepancy=discrepancy,
        checklist=checklist,
        raw_evidence=raw_evidence,
    )