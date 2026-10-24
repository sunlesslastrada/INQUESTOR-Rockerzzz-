import json
from io import BytesIO
from typing import Dict, Any, Optional
from PIL import Image
from google import genai
from google.genai import types

from config import settings
from schemas import LogoAuditResponse, ProductCategory

# Initialize Gemini Client
client = genai.Client(api_key=settings.GEMINI_API_KEY) if settings.GEMINI_API_KEY else None


async def audit_logo_image(image_bytes: bytes) -> LogoAuditResponse:
    """
    Tier-0: Autonomously identifies brand and inspects logo typography,
    symmetry, aspect ratio, and spoof anomalies using Gemini Vision.
    Halts (can_proceed=False) if the product is outside Electronics/Medicine scope.
    """
    # Fallback if no API key is provided during offline development
    if not client:
        return LogoAuditResponse(
            is_logo_valid=True,
            detected_brand="Unknown (No API Key)",
            detected_category=ProductCategory.UNSUPPORTED,
            confidence=0.5,
            anomalies_detected=["GEMINI_API_KEY_MISSING"],
            reasoning="Running in offline development mode without Gemini API key.",
            can_proceed=False,
        )

    try:
        # Load and convert image to verify integrity
        pil_image = Image.open(BytesIO(image_bytes))
        if pil_image.mode != "RGB":
            pil_image = pil_image.convert("RGB")

        prompt = """
You are a senior forensic anti-counterfeiting examiner specializing in brand emblem, typography, and logo authenticity.

Examine the provided cropped image of a product logo or packaging emblem:
1. Autonomously identify the brand or manufacturer from visual insignia or text.
2. Determine whether the primary category of this brand is strictly 'electronics', 'medicine', or 'unsupported' (e.g., footwear, apparel, food, beverages, automotive).
3. Inspect for:
   - Altered/spoofed typography or slight misspellings (e.g., 'Sorny', 'Abibas', altered fonts).
   - Distorted aspect ratios, uneven glyph weights, or crude vector artifacts.
   - Genuine trademark glyphs and proportion consistency.

Return ONLY valid JSON matching this exact structure:
{
  "is_logo_valid": true,
  "detected_brand": "BrandName",
  "detected_category": "electronics" | "medicine" | "unsupported",
  "confidence": 0.95,
  "anomalies_detected": ["List of anomalies, or empty if authentic"],
  "reasoning": "Clear 1-2 sentence forensic justification"
}
"""

        # Call Gemini Vision with JSON response constraint
        response = client.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=[pil_image, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,  # Low temperature for deterministic analysis
            ),
        )

        raw_text = response.text.strip()
        data = json.loads(raw_text)

        # Map string category to Enum
        cat_str = str(data.get("detected_category", "")).lower()
        if "elect" in cat_str:
            category = ProductCategory.ELECTRONICS
        elif "med" in cat_str or "pharma" in cat_str:
            category = ProductCategory.MEDICINE
        else:
            category = ProductCategory.UNSUPPORTED

        is_valid = bool(data.get("is_logo_valid", False))
        anomalies = data.get("anomalies_detected", [])

        # Enforce can_proceed constraint based on category support
        if category == ProductCategory.UNSUPPORTED:
            can_proceed = False
            anomalies.append("Unsupported category: Inquestor currently only audits Electronics and Medicine tracks.")
        else:
            can_proceed = True

        return LogoAuditResponse(
            is_logo_valid=is_valid,
            detected_brand=data.get("detected_brand", "Unknown"),
            detected_category=category,
            confidence=float(data.get("confidence", 0.8)),
            anomalies_detected=anomalies,
            reasoning=data.get("reasoning", "Autonomous inspection complete."),
            can_proceed=can_proceed,
        )

    except Exception as e:
        return LogoAuditResponse(
            is_logo_valid=False,
            detected_brand="Error",
            detected_category=ProductCategory.UNSUPPORTED,
            confidence=0.0,
            anomalies_detected=[f"Extraction error: {str(e)}"],
            reasoning="Vision audit failed to process image stream.",
            can_proceed=False,
        )
    
async def extract_packaging_text(image_bytes: bytes, category_hint: ProductCategory) -> Dict[str, Any]:
    """
    Tier-1: Reads natural text from packaging label or medicine foil.
    Transcribes Brand, Model/Drug Name, Serial/Batch Number, Expiry, and Mfg Date.
    """
    if not client:
        return {
            "brand_name": "Mock Brand",
            "model_or_drug_name": "Mock Model",
            "serial_or_batch_number": "MOCK-12345",
            "expiry_date": "2027-12-31",
            "mfg_date": "2024-01-01",
        }

    try:
        pil_image = Image.open(BytesIO(image_bytes))
        if pil_image.mode != "RGB":
            pil_image = pil_image.convert("RGB")

        prompt = f"""
You are a forensic packaging intake transcriber.
Analyze the packaging text, medicine blister foil, or device specification sticker in this image.
The product belongs to category: '{category_hint.value}'.

Extract and transcribe the following text fields into JSON. Do NOT guess or hallucinate—if a field is not visible, return null.

Fields to extract:
1. brand_name: The company or manufacturer name.
2. model_or_drug_name: The product model name (e.g., 'WH-1000XM5', 'ThinkPad X1') or pharmaceutical compound/brand (e.g., 'Augmentin 625 Duo', 'Paracetamol 500mg').
3. serial_or_batch_number: Serial number (for electronics) or Batch/Lot number (B.No. / Lot for medicines).
4. expiry_date: Expiration date in format 'YYYY-MM-DD' or 'YYYY-MM' (e.g. from 'EXP 08/2027' -> '2027-08').
5. mfg_date: Manufacturing date in format 'YYYY-MM-DD' or 'YYYY-MM' (e.g. from 'MFD 01/2024' -> '2024-01').

Return ONLY valid JSON matching this schema:
{{
  "brand_name": "string or null",
  "model_or_drug_name": "string or null",
  "serial_or_batch_number": "string or null",
  "expiry_date": "string or null",
  "mfg_date": "string or null"
}}
"""

        response = client.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=[pil_image, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )

        return json.loads(response.text.strip())

    except Exception:
        return {
            "brand_name": None,
            "model_or_drug_name": None,
            "serial_or_batch_number": None,
            "expiry_date": None,
            "mfg_date": None,
        }