import re
from io import BytesIO
from typing import Dict, Any, Optional
from PIL import Image
from pyzbar.pyzbar import decode, ZBarSymbol
from urllib.parse import urlparse

def decode_optical_codes(image_bytes: bytes) -> Dict[str, Any]:
    """
    Decodes 1D barcodes, 2D QR codes, and GS1 DataMatrix symbologies.
    Parses GS1 Application Identifiers (AIs) or URLs if present.
    """
    result = {
        "raw_code": None,
        "symbology": None,
        "barcode_gtin": None,
        "embedded_batch": None,
        "embedded_expiry": None,
        "embedded_serial": None,
        "qr_redirect_url": None,
    }

    try:
        pil_image = Image.open(BytesIO(image_bytes))
        # pyzbar works best on grayscale or 8-bit images
        decoded_objects = decode(pil_image)

        if not decoded_objects:
            return result

        # Inspect the primary detected code
        primary_obj = decoded_objects[0]
        raw_data = primary_obj.data.decode("utf-8", errors="ignore").strip()
        symbology = primary_obj.type  # e.g., 'EAN13', 'QRCODE', 'DATAMATRIX', 'CODE128'

        result["raw_code"] = raw_data
        result["symbology"] = symbology

        # 1. Check if the code is a URL (Anti-counterfeit QR redirect)
        parsed_url = urlparse(raw_data)
        if parsed_url.scheme in ("http", "https"):
            result["qr_redirect_url"] = raw_data

        # 2. Check for standard 1D Barcodes (digits only: UPC-A, EAN-8, EAN-13, ITF-14)
        if raw_data.isdigit() and len(raw_data) in (8, 12, 13, 14):
            result["barcode_gtin"] = raw_data

        # 3. Check for GS1 Application Identifier (AI) format (e.g., (01)...(10)...(17)...(21)...)
        # Matches formats with or without parentheses: (01)0890103000... or 010890103000...
        gtin_match = re.search(r"\(?01\)?(\d{14})", raw_data)
        if gtin_match:
            result["barcode_gtin"] = gtin_match.group(1)

        batch_match = re.search(r"\(?10\)?([A-Za-z0-9\-\/]+?)(?=\([0-9]{2}\)|$)", raw_data)
        if batch_match:
            result["embedded_batch"] = batch_match.group(1).strip()

        expiry_match = re.search(r"\(?17\)?(\d{6})", raw_data)
        if expiry_match:
            # GS1 date is YYMMDD -> Normalize to YYYY-MM-DD
            yymmdd = expiry_match.group(1)
            yy, mm, dd = yymmdd[:2], yymmdd[2:4], yymmdd[4:6]
            year = f"20{yy}"
            # Day '00' in GS1 represents last day of the month; default to 28 for safety
            day = "28" if dd == "00" else dd
            result["embedded_expiry"] = f"{year}-{mm}-{day}"

        serial_match = re.search(r"\(?21\)?([A-Za-z0-9\-\/]+?)(?=\([0-9]{2}\)|$)", raw_data)
        if serial_match:
            result["embedded_serial"] = serial_match.group(1).strip()

        return result

    except Exception:
        return result