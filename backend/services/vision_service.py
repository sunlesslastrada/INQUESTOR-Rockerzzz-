import json
from io import BytesIO
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
            can_proceed=True,
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
2. Determine whether the primary category of this brand is 'electronics', 'medicine', or 'unsupported'.
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
  "reasoning": "Clear 1-2 sentence forensic justification",
  "can_proceed": true
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

        # If it's an unsupported category, flag it clearly
        if category == ProductCategory.UNSUPPORTED and is_valid:
            anomalies.append("Category not currently covered in HackIIITD scope (supports Electronics & Medicine).")

        return LogoAuditResponse(
            is_logo_valid=is_valid,
            detected_brand=data.get("detected_brand", "Unknown"),
            detected_category=category,
            confidence=float(data.get("confidence", 0.8)),
            anomalies_detected=anomalies,
            reasoning=data.get("reasoning", "Autonomous inspection complete."),
            can_proceed=True,  # Allow frontend user to override even if suspicious
        )

    except Exception as e:
        # Fail safe without crashing server
        return LogoAuditResponse(
            is_logo_valid=False,
            detected_brand="Error",
            detected_category=ProductCategory.UNSUPPORTED,
            confidence=0.0,
            anomalies_detected=[f"Extraction error: {str(e)}"],
            reasoning="Vision audit failed to process image stream.",
            can_proceed=True,
        )