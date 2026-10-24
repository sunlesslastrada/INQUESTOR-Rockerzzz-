import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/tier0_models.dart';
import 'api_service.dart';

/// Network service communicating with the Tier 0 Inspection Backend endpoint.
/// Replaces all mock/placeholder logic with live multipart HTTP uploads.
class Tier0Service {
  final ApiService _apiService;

  Tier0Service({
    String? baseUrl,
    String? endpointPath,
    http.Client? client,
    ApiService? apiService,
  }) : _apiService = apiService ??
            ApiService(
              baseUrl: baseUrl,
              endpointPath: endpointPath,
              client: client,
            );

  String get baseUrl => _apiService.baseUrl;

  /// Uploads image bytes via multipart POST to the Tier 0 endpoint.
  /// Deserializes the dynamic response into a strongly-typed [Tier0Response].
  Future<Tier0Response> inspectImage({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    return _apiService.inspectTier0(
      imageBytes: imageBytes,
      filename: filename,
    );
  }

  void dispose() {
    _apiService.dispose();
  }
}
