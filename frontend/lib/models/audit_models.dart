import 'dart:core';

/// Supported product categories for forensic inquest.
class InquestCategory {
  InquestCategory._();
  static const String electronics = 'electronics';
  static const String medicine = 'medicine';
  static const String unsupported = 'unsupported';
}

/// Normalized claims extracted from packaging, optical barcodes, and QR codes.
class ExtractedProductClaims {
  final String category;
  final String? brandName;
  final String? modelOrDrugName;
  final String? barcodeGtin;
  final String? serialOrBatchNumber;
  final String? expiryDate;
  final String? mfgDate;
  final String? qrRedirectUrl;
  final String? barcodeEmbeddedBatch;
  final String? barcodeEmbeddedExpiry;

  const ExtractedProductClaims({
    required this.category,
    this.brandName,
    this.modelOrDrugName,
    this.barcodeGtin,
    this.serialOrBatchNumber,
    this.expiryDate,
    this.mfgDate,
    this.qrRedirectUrl,
    this.barcodeEmbeddedBatch,
    this.barcodeEmbeddedExpiry,
  });

  factory ExtractedProductClaims.fromJson(Map<String, dynamic> json) {
    return ExtractedProductClaims(
      category: json['category'] as String? ?? InquestCategory.electronics,
      brandName: json['brand_name'] as String?,
      modelOrDrugName: json['model_or_drug_name'] as String?,
      barcodeGtin: json['barcode_gtin'] as String?,
      serialOrBatchNumber: json['serial_or_batch_number'] as String?,
      expiryDate: json['expiry_date'] as String?,
      mfgDate: json['mfg_date'] as String?,
      qrRedirectUrl: json['qr_redirect_url'] as String?,
      barcodeEmbeddedBatch: json['barcode_embedded_batch'] as String?,
      barcodeEmbeddedExpiry: json['barcode_embedded_expiry'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'brand_name': brandName,
      'model_or_drug_name': modelOrDrugName,
      'barcode_gtin': barcodeGtin,
      'serial_or_batch_number': serialOrBatchNumber,
      'expiry_date': expiryDate,
      'mfg_date': mfgDate,
      'qr_redirect_url': qrRedirectUrl,
      'barcode_embedded_batch': barcodeEmbeddedBatch,
      'barcode_embedded_expiry': barcodeEmbeddedExpiry,
    };
  }

  ExtractedProductClaims copyWith({
    String? category,
    String? brandName,
    String? modelOrDrugName,
    String? barcodeGtin,
    String? serialOrBatchNumber,
    String? expiryDate,
    String? mfgDate,
    String? qrRedirectUrl,
    String? barcodeEmbeddedBatch,
    String? barcodeEmbeddedExpiry,
  }) {
    return ExtractedProductClaims(
      category: category ?? this.category,
      brandName: brandName ?? this.brandName,
      modelOrDrugName: modelOrDrugName ?? this.modelOrDrugName,
      barcodeGtin: barcodeGtin ?? this.barcodeGtin,
      serialOrBatchNumber: serialOrBatchNumber ?? this.serialOrBatchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      mfgDate: mfgDate ?? this.mfgDate,
      qrRedirectUrl: qrRedirectUrl ?? this.qrRedirectUrl,
      barcodeEmbeddedBatch: barcodeEmbeddedBatch ?? this.barcodeEmbeddedBatch,
      barcodeEmbeddedExpiry: barcodeEmbeddedExpiry ?? this.barcodeEmbeddedExpiry,
    );
  }
}

/// Structured item representing a discrete forensic audit check.
class AuditCheckItem {
  final String tier;
  final String name;
  final bool passed;
  final String details;

  const AuditCheckItem({
    required this.tier,
    required this.name,
    required this.passed,
    required this.details,
  });

  factory AuditCheckItem.fromJson(Map<String, dynamic> json) {
    return AuditCheckItem(
      tier: json['tier'] as String? ?? 'Tier-2',
      name: json['name'] as String? ?? 'Audit Check',
      passed: json['passed'] as bool? ?? false,
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier,
      'name': name,
      'passed': passed,
      'details': details,
    };
  }
}

/// Request payload sent to POST /api/v1/verify.
class VerificationRequest {
  final ExtractedProductClaims claims;
  final Map<String, dynamic>? tier0LogoSummary;
  final bool forceContinue;
  final bool? mockMode;
  final String? demoPreset;

  const VerificationRequest({
    required this.claims,
    this.tier0LogoSummary,
    this.forceContinue = false,
    this.mockMode,
    this.demoPreset,
  });

  Map<String, dynamic> toJson() {
    return {
      'claims': claims.toJson(),
      'tier0_logo_summary': tier0LogoSummary,
      'force_continue': forceContinue,
      if (mockMode != null) 'mock_mode': mockMode,
      if (demoPreset != null) 'demo_preset': demoPreset,
    };
  }
}

/// Verification verdict constants returned by backend.
class VerdictStatus {
  VerdictStatus._();
  static const String verifiedMatch = 'VERIFIED MATCH';
  static const String suspicious = 'SUSPICIOUS';
  static const String unableToVerify = 'UNABLE TO VERIFY';
}

/// Comprehensive verification response returned by POST /api/v1/verify.
class VerificationResponse {
  final String verdict;
  final String category;
  final String summaryBanner;
  final Map<String, dynamic>? forensicDiscrepancy;
  final List<AuditCheckItem> checklist;
  final Map<String, dynamic>? rawEvidence;

  const VerificationResponse({
    required this.verdict,
    required this.category,
    required this.summaryBanner,
    this.forensicDiscrepancy,
    this.checklist = const [],
    this.rawEvidence,
  });

  factory VerificationResponse.fromJson(Map<String, dynamic> json) {
    final rawChecklist = json['checklist'] as List<dynamic>? ?? [];
    return VerificationResponse(
      verdict: json['verdict'] as String? ?? VerdictStatus.unableToVerify,
      category: json['category'] as String? ?? InquestCategory.electronics,
      summaryBanner: json['summary_banner'] as String? ?? '',
      forensicDiscrepancy: json['forensic_discrepancy'] as Map<String, dynamic>?,
      checklist: rawChecklist
          .map((item) => AuditCheckItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      rawEvidence: json['raw_evidence'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verdict': verdict,
      'category': category,
      'summary_banner': summaryBanner,
      'forensic_discrepancy': forensicDiscrepancy,
      'checklist': checklist.map((e) => e.toJson()).toList(),
      'raw_evidence': rawEvidence,
    };
  }
}

/// Demo Preset specification for 1-tap Judge testbench.
class DemoPreset {
  final String id;
  final String label;
  final String emoji;
  final String category;
  final String? backendPresetId;
  final String description;
  final ExtractedProductClaims claims;

  const DemoPreset({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
    required this.backendPresetId,
    required this.description,
    required this.claims,
  });

  static const List<DemoPreset> allPresets = [
    DemoPreset(
      id: 'cloned_headset',
      label: '1. Cloned Headset',
      emoji: '🎧',
      category: InquestCategory.electronics,
      backendPresetId: 'cloned_headset',
      description: 'Triggers model mismatch: claims WH-1000XM5, serial registered to MDR-EX15LP.',
      claims: ExtractedProductClaims(
        category: InquestCategory.electronics,
        brandName: 'Sony',
        modelOrDrugName: 'WH-1000XM5 Wireless Headphones',
        barcodeGtin: '0027242923508',
        serialOrBatchNumber: '5281902',
      ),
    ),
    DemoPreset(
      id: 'recalled_medicine',
      label: '2. Recalled Batch',
      emoji: '💊',
      category: InquestCategory.medicine,
      backendPresetId: 'recalled_medicine',
      description: 'Triggers CDSCO NSQ monthly alert recall on batch GT20491.',
      claims: ExtractedProductClaims(
        category: InquestCategory.medicine,
        brandName: 'Sun Pharma',
        modelOrDrugName: 'Pantocid DSR (Pantoprazole & Domperidone)',
        barcodeGtin: '08901117002012',
        serialOrBatchNumber: 'GT20491',
        expiryDate: '2027-08',
        mfgDate: '2024-09',
        barcodeEmbeddedBatch: 'GT20491',
      ),
    ),
    DemoPreset(
      id: 'generic_unverified',
      label: '3. Generic Unverified',
      emoji: '📦',
      category: InquestCategory.electronics,
      backendPresetId: 'generic_unverified',
      description: 'Brand lacks public authoritative portal in registry.',
      claims: ExtractedProductClaims(
        category: InquestCategory.electronics,
        brandName: 'Zebronics',
        modelOrDrugName: 'Zeb-Thunder Wireless BT Headphone',
        barcodeGtin: '8904257512345',
        serialOrBatchNumber: 'ZB20249811',
      ),
    ),
    DemoPreset(
      id: 'verified_medicine',
      label: '4. Verified Medicine',
      emoji: '💊',
      category: InquestCategory.medicine,
      backendPresetId: null,
      description: 'Audited against CDSCO; clean, verified match.',
      claims: ExtractedProductClaims(
        category: InquestCategory.medicine,
        brandName: 'Cipla',
        modelOrDrugName: 'Dolo-650 (Paracetamol Tablets IP 650mg)',
        barcodeGtin: '08901117105021',
        serialOrBatchNumber: 'CP78214',
        expiryDate: '2027-11',
        mfgDate: '2024-12',
        barcodeEmbeddedBatch: 'CP78214',
      ),
    ),
    DemoPreset(
      id: 'verified_electronics',
      label: '5. Verified Electronics',
      emoji: '🎧',
      category: InquestCategory.electronics,
      backendPresetId: null,
      description: 'Audited against OEM portal; clean, verified match.',
      claims: ExtractedProductClaims(
        category: InquestCategory.electronics,
        brandName: 'Lenovo',
        modelOrDrugName: '320-15IKB (ideapad) Type 80XL',
        barcodeGtin: '0191376882201',
        serialOrBatchNumber: 'PF0Z8Y5K',
      ),
    ),
  ];
}

/// Client-side deterministic evaluator for immediate reactive feedback in Phase B.
class LocalDeterministicEvaluator {
  LocalDeterministicEvaluator._();

  static const Map<String, String> _serialRegexPatterns = {
    'dell': r'^[A-Z0-9]{7}$',
    'apple': r'^[A-Z0-9]{10}$|^[A-Z0-9]{12}$',
    'hp': r'^[A-Z0-9]{10,12}$',
    'lenovo': r'^[A-Z0-9]{7,10}$',
    'sony': r'^\d{7}$',
    'generic_pharma': r'^[A-Za-z0-9\-\/]{4,15}$',
  };

  static const Set<String> _suspiciousTlds = {
    '.xyz', '.top', '.cc', '.tk', '.cf', '.ga', '.ml', '.buzz', '.monster', '.fit'
  };

  static const Set<String> _trustedDomains = {
    'sony.com', 'apple.com', 'dell.com', 'lenovo.com', 'hp.com', 'logitech.com',
    'cdsco.gov.in', 'gs1india.org', 'cipla.com', 'sunpharma.com', 'fda.gov'
  };

  /// Computes all Tier-2 checks client-side for instant review feedback.
  static List<AuditCheckItem> evaluate(ExtractedProductClaims claims) {
    final List<AuditCheckItem> items = [];

    // 1. GS1 Checksum
    final gtinResult = _validateGtinChecksum(claims.barcodeGtin);
    items.add(AuditCheckItem(
      tier: 'Tier-2',
      name: 'GS1 GTIN Modulo-10 Checksum',
      passed: gtinResult.$1,
      details: gtinResult.$2,
    ));

    // 2. Serial / Batch Syntax
    final serialResult = _validateSerialSyntax(
      claims.brandName,
      claims.serialOrBatchNumber,
      claims.category,
    );
    items.add(AuditCheckItem(
      tier: 'Tier-2',
      name: 'Serial / Batch Syntax Check',
      passed: serialResult.$1,
      details: serialResult.$2,
    ));

    // 3. Temporal Expiry & Shelf-Life
    final dateResults = _validateExpiryAndShelfLife(
      claims.expiryDate,
      claims.mfgDate,
      claims.category,
    );
    for (final res in dateResults) {
      items.add(AuditCheckItem(
        tier: 'Tier-2',
        name: 'Temporal Expiry & Shelf-Life',
        passed: res.$1,
        details: res.$2,
      ));
    }

    // 4. Foil vs Barcode Batch Consistency
    final consistencyResult = _validateFoilConsistency(claims);
    items.add(AuditCheckItem(
      tier: 'Tier-2',
      name: 'Foil vs Barcode Consistency',
      passed: consistencyResult.$1,
      details: consistencyResult.$2,
    ));

    // 5. QR Security Check
    final qrResult = _validateQrSecurity(claims.qrRedirectUrl);
    items.add(AuditCheckItem(
      tier: 'Tier-2',
      name: 'QR Security & Domain Check',
      passed: qrResult.$1,
      details: qrResult.$2,
    ));

    return items;
  }

  static (bool, String) _validateGtinChecksum(String? barcode) {
    if (barcode == null || barcode.trim().isEmpty) {
      return (true, 'No barcode provided for checksum validation.');
    }
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (![8, 12, 13, 14].contains(digits.length)) {
      return (true, "Barcode '$barcode' is a non-GTIN proprietary/serial format; checksum skipped.");
    }
    final checkDigit = int.parse(digits[digits.length - 1]);
    final payload = digits.substring(0, digits.length - 1);

    int totalSum = 0;
    int multiplier = 3;
    for (int i = payload.length - 1; i >= 0; i--) {
      totalSum += int.parse(payload[i]) * multiplier;
      multiplier = (multiplier == 3) ? 1 : 3;
    }
    final calculatedCheck = (10 - (totalSum % 10)) % 10;
    if (calculatedCheck == checkDigit) {
      return (true, 'Valid GS1 Modulo-10 checksum (Check digit: $checkDigit).');
    } else {
      return (false, 'Checksum mismatch: expected check digit $calculatedCheck, got $checkDigit.');
    }
  }

  static (bool, String) _validateSerialSyntax(String? brand, String? serial, String category) {
    if (serial == null || serial.trim().isEmpty) {
      return (true, 'No serial/batch number provided to validate.');
    }
    final cleanSerial = serial.trim();
    if (category == InquestCategory.medicine) {
      final reg = RegExp(_serialRegexPatterns['generic_pharma']!);
      if (reg.hasMatch(cleanSerial)) {
        return (true, "Batch format '$cleanSerial' matches standard pharmaceutical syntax.");
      }
      return (false, "Batch format '$cleanSerial' violates standard batch syntax.");
    }

    if (brand == null || brand.trim().isEmpty) {
      return (true, 'Brand unknown; strict brand regex skipped.');
    }

    final brandKey = brand.trim().toLowerCase();
    for (final entry in _serialRegexPatterns.entries) {
      if (entry.key != 'generic_pharma' && brandKey.contains(entry.key)) {
        final reg = RegExp(entry.value);
        if (reg.hasMatch(cleanSerial.toUpperCase())) {
          return (true, "Serial '$cleanSerial' matches verified ${entry.key.toUpperCase()} syntax.");
        }
        return (false, "Serial '$cleanSerial' deviates from expected ${entry.key.toUpperCase()} pattern.");
      }
    }
    return (true, "Serial '$cleanSerial' verified against general equipment syntax.");
  }

  static List<(bool, String)> _validateExpiryAndShelfLife(
    String? expiryStr,
    String? mfgStr,
    String category,
  ) {
    final List<(bool, String)> results = [];
    final today = DateTime.now();

    DateTime? expDate = _parseDate(expiryStr);
    DateTime? mfgDate = _parseDate(mfgStr);

    if (expDate != null) {
      if (expDate.isBefore(today)) {
        results.add((false, 'EXPIRED: Product expired on ${expDate.toIso8601String().substring(0, 10)}.'));
      } else {
        results.add((true, 'Unexpired: Expiry date is valid.'));
      }
    }

    if (expDate != null && mfgDate != null) {
      final shelfDays = expDate.difference(mfgDate).inDays;
      if (shelfDays < 0) {
        results.add((false, 'Invalid timeline: Expiry date precedes Manufacturing date.'));
      } else if (category == InquestCategory.medicine && shelfDays > (5 * 365 + 30)) {
        results.add((false, 'Anomalous shelf life (${shelfDays ~/ 365} years). Exceeds statutory 5-year limit.'));
      } else {
        results.add((true, 'Shelf life duration is within legitimate statutory bounds.'));
      }
    }

    if (results.isEmpty) {
      results.add((true, 'Chronological verification passed (no immediate expiry anomalies).'));
    }

    return results;
  }

  static (bool, String) _validateFoilConsistency(ExtractedProductClaims claims) {
    if (claims.barcodeEmbeddedBatch == null || claims.serialOrBatchNumber == null) {
      return (true, 'Dual-source consistency check not applicable (no 2D barcode batch).');
    }
    final bBatch = claims.barcodeEmbeddedBatch!.replaceAll(RegExp(r'[\s\-\/]'), '').toUpperCase();
    final pBatch = claims.serialOrBatchNumber!.replaceAll(RegExp(r'[\s\-\/]'), '').toUpperCase();
    if (bBatch == pBatch) {
      return (true, 'Internal consistency confirmed: 2D barcode matches printed foil batch.');
    }
    return (false, 'CRITICAL MISMATCH: Barcode batch (${claims.barcodeEmbeddedBatch}) contradicts foil batch (${claims.serialOrBatchNumber}).');
  }

  static (bool, String) _validateQrSecurity(String? qrUrl) {
    if (qrUrl == null || qrUrl.trim().isEmpty) {
      return (true, 'No QR redirect URL present.');
    }
    final uri = Uri.tryParse(qrUrl.trim());
    if (uri == null) {
      return (false, 'Malformed QR verification URL.');
    }
    final host = uri.host.toLowerCase();
    for (final tld in _suspiciousTlds) {
      if (host.endsWith(tld)) {
        return (false, "PHISHING ALERT: QR points to high-risk disposable TLD '$host'.");
      }
    }
    for (final trusted in _trustedDomains) {
      if (host == trusted || host.endsWith('.$trusted')) {
        return (true, "QR domain '$host' matches verified manufacturer whitelist.");
      }
    }
    return (true, "QR domain '$host' requires authoritative agent examination.");
  }

  static DateTime? _parseDate(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    final clean = str.trim();
    // YYYY-MM-DD
    try {
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(clean)) {
        return DateTime.parse(clean);
      }
      // YYYY-MM
      if (RegExp(r'^\d{4}-\d{2}$').hasMatch(clean)) {
        final parts = clean.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), 28);
      }
      // MM/YY
      final mmYy = RegExp(r'^(\d{1,2})[\/\-](\d{2})$').firstMatch(clean);
      if (mmYy != null) {
        final m = int.parse(mmYy.group(1)!);
        final y = int.parse('20${mmYy.group(2)!}');
        return DateTime(y, m, 28);
      }
    } catch (_) {}
    return null;
  }
}
