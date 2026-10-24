from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class ProductCategory(str, Enum):
    ELECTRONICS = "electronics"
    MEDICINE = "medicine"
    UNSUPPORTED = "unsupported"


class VerdictStatus(str, Enum):
    VERIFIED_MATCH = "VERIFIED MATCH"
    SUSPICIOUS = "SUSPICIOUS"
    UNABLE_TO_VERIFY = "UNABLE TO VERIFY"


# TIER-0: LOGO AUDIT SCHEMAS

class LogoAuditResponse(BaseModel):
    is_logo_valid: bool = Field(..., description="Whether the logo appears structurally authentic")
    detected_brand: Optional[str] = Field(None, description="Brand name identified autonomously from emblem/text")
    detected_category: ProductCategory = Field(default=ProductCategory.UNSUPPORTED, description="Detected category")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Model confidence score")
    anomalies_detected: List[str] = Field(default_factory=list, description="Specific visual defects or spoof indicators")
    reasoning: str = Field(..., description="Forensic rationale for the visual assessment")
    can_proceed: bool = Field(True, description="Whether the app flow can proceed to back-of-box scan")


# TIER-1 & HUMAN-IN-THE-LOOP EXTRACT SCHEMAS

class ExtractedProductClaims(BaseModel):
    category: ProductCategory = Field(default=ProductCategory.ELECTRONICS)
    brand_name: Optional[str] = None
    model_or_drug_name: Optional[str] = None
    barcode_gtin: Optional[str] = None
    serial_or_batch_number: Optional[str] = None
    expiry_date: Optional[str] = None  # Format: YYYY-MM-DD or YYYY-MM
    mfg_date: Optional[str] = None
    qr_redirect_url: Optional[str] = None
    barcode_embedded_batch: Optional[str] = None
    barcode_embedded_expiry: Optional[str] = None


# VERIFICATION & AUDIT CHECKLIST SCHEMAS

class VerificationRequest(BaseModel):
    claims: ExtractedProductClaims
    tier0_logo_summary: Optional[Dict[str, Any]] = None
    force_continue: bool = Field(False, description="Continue audit despite Tier-0/Tier-2 red flags")
    mock_mode: Optional[bool] = Field(None, description="Override global MOCK_MODE per request")
    demo_preset: Optional[str] = Field(
        None,
        description="Optional judge preset: 'cloned_headset' | 'recalled_medicine' | 'generic_unverified'"
    )


class AuditCheckItem(BaseModel):
    tier: str  # "Tier-0", "Tier-2", "Tier-3"
    name: str  # e.g., "GS1 Modulo-10 Checksum", "Serial Syntax Regex"
    passed: bool
    details: str


class VerificationResponse(BaseModel):
    verdict: VerdictStatus
    category: ProductCategory
    summary_banner: str
    forensic_discrepancy: Optional[Dict[str, Any]] = None
    checklist: List[AuditCheckItem] = Field(default_factory=list)
    raw_evidence: Optional[Dict[str, Any]] = None