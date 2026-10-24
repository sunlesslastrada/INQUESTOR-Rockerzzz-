import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/tier0_models.dart';

/// Centralized configuration and base URL management for the backend APIs.
class ApiConfig {
  ApiConfig._();

  /// Default backend base URL:
  /// - Web / Desktop: http://127.0.0.1:8000
  /// - Android Emulator: http://10.0.2.2:8000
  /// Can be overridden via --dart-define=API_BASE_URL=...
  static String get defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}

/// Custom exception thrown when API communication or server validation fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException(
    this.message, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() => message;
}

/// Network service responsible for communicating with the Inquestor backend.
class ApiService {
  final String baseUrl;
  final String endpointPath;
  final http.Client _client;

  ApiService({
    String? baseUrl,
    String? endpointPath,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
        endpointPath = endpointPath ?? '/api/v1/verify-logo',
        _client = client ?? http.Client();

  /// Target Endpoint: POST /api/v1/verify-logo
  /// (with automatic fallback to /api/v1/tier0/inspect if route returns 404)
  /// Sends the selected/captured image bytes as multipart form field 'file'.
  Future<Tier0Response> inspectTier0({
    required Uint8List imageBytes,
    required String filename,
    String? pathOverride,
  }) async {
    final path = pathOverride ?? endpointPath;
    final uri = Uri.parse('$baseUrl$path');

    final isPng = filename.toLowerCase().endsWith('.png');
    final mediaType = MediaType('image', isPng ? 'png' : 'jpeg');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request).timeout(
        const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out while contacting backend at $baseUrl. Ensure FastAPI is running.',
      );
    } catch (e) {
      throw ApiException(
        'Unable to connect to backend at $baseUrl. Check if the server is active.',
        details: e,
      );
    }

    // Auto-fallback: if primary route returned 404 and no manual pathOverride was specified,
    // attempt alternate endpoint path (e.g. /api/v1/tier0/inspect <-> /api/v1/verify-logo)
    if (streamedResponse.statusCode == 404 && pathOverride == null) {
      final fallbackPath = path == '/api/v1/verify-logo'
          ? '/api/v1/tier0/inspect'
          : '/api/v1/verify-logo';
      try {
        return await inspectTier0(
          imageBytes: imageBytes,
          filename: filename,
          pathOverride: fallbackPath,
        );
      } catch (_) {
        // Fall through to standard non-200 error handling below
      }
    }

    final respBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      String errorMessage = 'Backend returned HTTP ${streamedResponse.statusCode}';
      try {
        final decoded = jsonDecode(respBody);
        if (decoded is Map && decoded.containsKey('detail')) {
          errorMessage = '${decoded['detail']} (HTTP ${streamedResponse.statusCode})';
        }
      } catch (_) {}
      throw ApiException(errorMessage, statusCode: streamedResponse.statusCode);
    }

    try {
      final dynamic decoded = jsonDecode(respBody);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Invalid JSON response format received from backend.');
      }
      return Tier0Response.fromJson(decoded);
    } on FormatException catch (e) {
      throw ApiException('Failed to parse backend JSON response: ${e.message}');
    }
  }

  void dispose() {
    _client.close();
  }
}
