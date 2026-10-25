import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/audit_models.dart';
import 'api_service.dart';

/// Network service responsible for Tier-1 extraction and Master Verification pipeline.
class AuditService {
  final String baseUrl;
  final http.Client _client;

  AuditService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
        _client = client ?? http.Client();

  /// Tier-1 Intake: POST /api/v1/extract
  /// Accepts packaging image, barcode image, and optional QR image.
  Future<ExtractedProductClaims> extractClaims({
    required String category,
    required Uint8List packagingBytes,
    required String packagingFilename,
    required Uint8List barcodeBytes,
    required String barcodeFilename,
    Uint8List? qrBytes,
    String? qrFilename,
    bool mockFallback = true,
    String? fallbackPreset,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/extract');

    final request = http.MultipartRequest('POST', uri);
    request.fields['category'] = category;

    // 1. Packaging text image
    final isPngPkg = packagingFilename.toLowerCase().endsWith('.png');
    request.files.add(
      http.MultipartFile.fromBytes(
        'packaging_image',
        packagingBytes,
        filename: packagingFilename,
        contentType: MediaType('image', isPngPkg ? 'png' : 'jpeg'),
      ),
    );

    // 2. Barcode / DataMatrix image
    final isPngBarcode = barcodeFilename.toLowerCase().endsWith('.png');
    request.files.add(
      http.MultipartFile.fromBytes(
        'barcode_image',
        barcodeBytes,
        filename: barcodeFilename,
        contentType: MediaType('image', isPngBarcode ? 'png' : 'jpeg'),
      ),
    );

    // 3. Optional separate QR image
    if (qrBytes != null && qrFilename != null) {
      final isPngQr = qrFilename.toLowerCase().endsWith('.png');
      request.files.add(
        http.MultipartFile.fromBytes(
          'qr_image',
          qrBytes,
          filename: qrFilename,
          contentType: MediaType('image', isPngQr ? 'png' : 'jpeg'),
        ),
      );
    }

    try {
      final streamedResponse = await _client.send(request).timeout(
        const Duration(seconds: 25),
      );

      final respBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final dynamic decoded = jsonDecode(respBody);
        if (decoded is Map<String, dynamic>) {
          return ExtractedProductClaims.fromJson(decoded);
        }
      }

      // If backend returned non-200 and mockFallback is allowed
      if (mockFallback) {
        return _getMockClaimsForCategory(category, fallbackPreset);
      }

      String errorMessage = 'Extraction failed (HTTP ${streamedResponse.statusCode})';
      try {
        final decoded = jsonDecode(respBody);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMessage = '${decoded['detail']} (HTTP ${streamedResponse.statusCode})';
        }
      } catch (_) {}
      throw ApiException(errorMessage, statusCode: streamedResponse.statusCode);
    } on TimeoutException {
      if (mockFallback) {
        return _getMockClaimsForCategory(category, fallbackPreset);
      }
      throw ApiException('Extraction timed out while contacting $baseUrl/api/v1/extract.');
    } catch (e) {
      if (e is ApiException) rethrow;
      if (mockFallback) {
        return _getMockClaimsForCategory(category, fallbackPreset);
      }
      throw ApiException('Unable to connect to backend at $baseUrl for extraction.', details: e);
    }
  }

  /// Master Verification: POST /api/v1/verify
  /// Executes Tier-2 rules engine and Tier-3 TinyFish web investigation.
  Future<VerificationResponse> verifyProduct(VerificationRequest request) async {
    final uri = Uri.parse('$baseUrl/api/v1/verify');

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return VerificationResponse.fromJson(decoded);
        }
      }

      // If backend returned non-200 and mock mode is requested
      if (request.mockMode == true) {
        return _getMockVerificationResponse(request);
      }

      String errorMessage = 'Verification returned HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMessage = '${decoded['detail']} (HTTP ${response.statusCode})';
        }
      } catch (_) {}
      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on TimeoutException {
      if (request.mockMode == true) {
        return _getMockVerificationResponse(request);
      }
      throw ApiException('Portal verification timed out after 45s. Toggle demo preset or retry.', statusCode: 408);
    } catch (e) {
      if (e is ApiException) rethrow;
      if (request.mockMode == true) {
        return _getMockVerificationResponse(request);
      }
      throw ApiException('Unable to reach backend at $baseUrl/api/v1/verify.', details: e);
    }
  }

  ExtractedProductClaims _getMockClaimsForCategory(String category, String? preset) {
    for (final p in DemoPreset.allPresets) {
      if (p.id == preset || p.backendPresetId == preset) {
        return p.claims;
      }
    }
    if (category == InquestCategory.medicine) {
      return DemoPreset.allPresets[3].claims; // Verified Medicine
    }
    return DemoPreset.allPresets[4].claims; // Verified Electronics
  }

  VerificationResponse _getMockVerificationResponse(VerificationRequest req) {
    final category = req.claims.category;
    final preset = req.demoPreset;
    final serial = req.claims.serialOrBatchNumber ?? 'UNKNOWN';

    if (preset == 'cloned_headset') {
      return VerificationResponse(
        verdict: VerdictStatus.suspicious,
        category: category,
        summaryBanner: 'Counterfeit Risk Detected: Contradiction found between packaging claims and authoritative records.',
        forensicDiscrepancy: {
          'field': 'Model / Serial Mismatch',
          'packaging_claim': req.claims.modelOrDrugName ?? 'WH-1000XM5',
          'official_record': "Serial registered to 'Sony MDR-EX15LP Basic Wired Earphones'",
        },
        checklist: [
          const AuditCheckItem(tier: 'Tier-0', name: 'Visual Brand & Emblem Audit', passed: true, details: "Brand 'Sony': Visual geometry validated."),
          const AuditCheckItem(tier: 'Tier-2', name: 'GS1 GTIN Modulo-10 Checksum', passed: true, details: 'Valid GS1 Modulo-10 checksum.'),
          const AuditCheckItem(tier: 'Tier-2', name: 'Serial / Batch Syntax Check', passed: true, details: "Serial '5281902' matches verified SONY syntax."),
          AuditCheckItem(tier: 'Tier-3', name: 'OEM Warranty Registry Cross-Examination', passed: false, details: "Serial '$serial' registered to 'Sony MDR-EX15LP' (Model Mismatch)."),
        ],
        rawEvidence: {
          'simulation_mode': true,
          'preset': 'cloned_headset',
          'registered_model': 'Sony MDR-EX15LP Basic Wired Earphones',
          'status': 'COMPLETED',
        },
      );
    }

    if (preset == 'recalled_medicine') {
      return VerificationResponse(
        verdict: VerdictStatus.suspicious,
        category: category,
        summaryBanner: 'Critical Health Alert: Batch flagged in CDSCO Not of Standard Quality (NSQ) Drug Alert list.',
        forensicDiscrepancy: {
          'field': 'Statutory Quality Recall',
          'packaging_claim': "Batch '$serial' (Active)",
          'official_record': 'CDSCO Monthly NSQ Drug Alert: Declared Not of Standard Quality',
        },
        checklist: [
          const AuditCheckItem(tier: 'Tier-0', name: 'Visual Brand & Emblem Audit', passed: true, details: "Brand 'Sun Pharma': Emblem cleared."),
          const AuditCheckItem(tier: 'Tier-2', name: 'GS1 GTIN Modulo-10 Checksum', passed: true, details: 'Valid GS1 Modulo-10 checksum.'),
          const AuditCheckItem(tier: 'Tier-2', name: 'Serial / Batch Syntax Check', passed: true, details: 'Batch format matches pharmaceutical standards.'),
          AuditCheckItem(tier: 'Tier-3', name: 'CDSCO National Drug Recall Database Audit', passed: false, details: "Batch '$serial' declared Not of Standard Quality (NSQ)."),
        ],
        rawEvidence: {
          'simulation_mode': true,
          'preset': 'recalled_medicine',
          'is_recalled': true,
          'recall_notice': 'CDSCO Monthly NSQ Drug Alert Notice',
        },
      );
    }

    if (preset == 'generic_unverified') {
      return const VerificationResponse(
        verdict: VerdictStatus.unableToVerify,
        category: InquestCategory.electronics,
        summaryBanner: 'Unable to Verify: Packaging syntax passed deterministic checks, but no public authoritative verification registry is available for this brand.',
        checklist: [
          AuditCheckItem(tier: 'Tier-0', name: 'Visual Brand & Emblem Audit', passed: true, details: 'Visual brand inspection recorded.'),
          AuditCheckItem(tier: 'Tier-2', name: 'GS1 GTIN Modulo-10 Checksum', passed: true, details: 'Valid GS1 Modulo-10 checksum.'),
          AuditCheckItem(tier: 'Tier-2', name: 'Serial / Batch Syntax Check', passed: true, details: 'Equipment serial format accepted.'),
          AuditCheckItem(tier: 'Tier-3', name: 'Authoritative OEM Portal Investigation', passed: false, details: 'Brand lacks public online registry portal.'),
        ],
        rawEvidence: {
          'simulation_mode': true,
          'status': 'SKIPPED_NO_PORTAL',
        },
      );
    }

    // Default Verified Match
    return VerificationResponse(
      verdict: VerdictStatus.verifiedMatch,
      category: category,
      summaryBanner: 'Information Match Confirmed. Note: Digital verification confirms packaging data matches official records.',
      checklist: [
        const AuditCheckItem(tier: 'Tier-0', name: 'Visual Brand & Emblem Audit', passed: true, details: 'Visual brand inspection cleared.'),
        const AuditCheckItem(tier: 'Tier-2', name: 'GS1 GTIN Modulo-10 Checksum', passed: true, details: 'Valid GS1 Modulo-10 checksum.'),
        const AuditCheckItem(tier: 'Tier-2', name: 'Serial / Batch Syntax Check', passed: true, details: 'Batch / serial syntax verified against manufacturer standard.'),
        const AuditCheckItem(tier: 'Tier-2', name: 'Temporal Expiry & Shelf-Life', passed: true, details: 'Shelf life duration is within legitimate statutory bounds.'),
        AuditCheckItem(tier: 'Tier-3', name: category == InquestCategory.medicine ? 'CDSCO National Drug Recall Database Audit' : 'OEM Warranty Registry Cross-Examination', passed: true, details: category == InquestCategory.medicine ? 'Audited against CDSCO NSQ portal. No active recall alerts found.' : "Serial number verified on manufacturer portal. Model matched."),
      ],
      rawEvidence: {
        'simulation_mode': true,
        'verified': true,
      },
    );
  }

  void dispose() {
    _client.close();
  }
}
