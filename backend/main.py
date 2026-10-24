from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from schemas import LogoAuditResponse
from services.vision_service import audit_logo_image

from typing import Optional
from fastapi import Form
from schemas import ExtractedProductClaims, ProductCategory
from services.barcode_service import decode_optical_codes
from services.vision_service import extract_packaging_text

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


# TIER-0: AUTONOMOUS LOGO AUDIT ROUTE

@app.post(
    f"{settings.API_V1_PREFIX}/verify-logo",
    response_model=LogoAuditResponse,
    tags=["Tier-0 Logo Audit"],
)
async def verify_logo(file: UploadFile = File(...)):
    """
    Accepts a cropped image of the front logo/emblem.
    Uses Gemini Vision to identify the brand, detect category,
    and spot visual spoofing before entering full back-of-box intake.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Invalid file type. Please upload an image file (PNG/JPEG/WEBP).",
        )

    contents = await file.read()
    result = await audit_logo_image(contents)
    return result


@app.post(
    f"{settings.API_V1_PREFIX}/extract",
    response_model=ExtractedProductClaims,
    tags=["Tier-1 Intake"],
)
async def extract_product_data(
    category: ProductCategory = Form(ProductCategory.ELECTRONICS),
    packaging_image: UploadFile = File(..., description="Image crop containing packaging text/foil"),
    barcode_image: UploadFile = File(..., description="Image crop containing 1D barcode or 2D DataMatrix"),
    qr_image: Optional[UploadFile] = File(None, description="Optional separate QR code image"),
):
    """
    Tier-1 Intake Endpoint:
    1. pyzbar decodes barcode_image (and optional qr_image) for GTIN, GS1 AIs, or URLs.
    2. Gemini Vision extracts natural text from packaging_image.
    3. Merges claims into an ExtractedProductClaims payload for Human-in-the-Loop review.
    """
    # Read files
    pkg_bytes = await packaging_image.read()
    barcode_bytes = await barcode_image.read()

    # 1. Barcode / DataMatrix extraction via pyzbar
    barcode_data = decode_optical_codes(barcode_bytes)

    # 2. Optional separate QR crop check
    qr_url = barcode_data.get("qr_redirect_url")
    if qr_image:
        qr_bytes = await qr_image.read()
        qr_data = decode_optical_codes(qr_bytes)
        if qr_data.get("qr_redirect_url"):
            qr_url = qr_data["qr_redirect_url"]

    # 3. Packaging text extraction via Gemini Vision
    text_data = await extract_packaging_text(pkg_bytes, category)

    # 4. Synthesize into ExtractedProductClaims
    # Prefer serial/batch from 2D barcode if available, fallback to printed text
    serial_or_batch = (
        text_data.get("serial_or_batch_number")
        or barcode_data.get("embedded_serial")
        or barcode_data.get("embedded_batch")
    )

    claims = ExtractedProductClaims(
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

    return claims