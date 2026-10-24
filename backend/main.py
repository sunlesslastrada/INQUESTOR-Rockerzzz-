from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from schemas import LogoAuditResponse
from services.vision_service import audit_logo_image

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