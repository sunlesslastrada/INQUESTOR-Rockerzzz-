import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inquestor/models/tier0_models.dart';
import 'package:inquestor/services/api_service.dart';

void main() {
  group('ApiService & ApiConfig', () {
    test('ApiConfig provides default URLs correctly', () {
      expect(ApiConfig.defaultBaseUrl, contains('http://'));
    });

    test(
        'inspectTier0 sends multipart request to /api/v1/verify-logo and deserializes response',
        () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        expect(request.url.path, equals('/api/v1/verify-logo'));
        expect(request.method, equals('POST'));
        expect(request is http.MultipartRequest, isTrue);

        final multipart = request as http.MultipartRequest;
        expect(multipart.files.length, equals(1));
        expect(multipart.files.first.field, equals('file'));
        expect(multipart.files.first.filename, equals('logo.png'));

        final responseJson = {
          'is_logo_valid': true,
          'detected_brand': 'Apple',
          'detected_category': 'electronics',
          'confidence': 0.97,
          'anomalies_detected': <String>[],
          'reasoning': 'Authentic Apple bite geometry validated.',
          'can_proceed': true,
        };

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(responseJson))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        baseUrl: 'http://test-server:8000',
        client: mockClient,
      );

      final result = await apiService.inspectTier0(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'logo.png',
      );

      expect(result.isLogoValid, isTrue);
      expect(result.detectedBrand, equals('Apple'));
      expect(result.confidence, equals(0.97));
      expect(result.canProceed, isTrue);
    });

    test(
        'inspectTier0 falls back to /api/v1/tier0/inspect if primary endpoint returns 404',
        () async {
      int requestCount = 0;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        requestCount++;
        if (request.url.path == '/api/v1/verify-logo') {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'detail': 'Not Found'}))),
            404,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/tier0/inspect') {
          final responseJson = {
            'is_logo_valid': true,
            'detected_brand': 'HP',
            'detected_category': 'electronics',
            'confidence': 0.98,
            'anomalies_detected': <String>[],
            'reasoning': 'Authentic HP emblem.',
            'can_proceed': true,
          };
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(responseJson))),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.StreamedResponse(Stream.empty(), 404);
      });

      final apiService = ApiService(
        baseUrl: 'http://test-server:8000',
        client: mockClient,
      );

      final result = await apiService.inspectTier0(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'logo.png',
      );

      expect(requestCount, equals(2));
      expect(result.isLogoValid, isTrue);
      expect(result.detectedBrand, equals('HP'));
    });

    test('inspectTier0 throws ApiException on non-200 status code', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final errorJson = {'detail': 'Invalid file type. Upload an image.'};
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(errorJson))),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(
        baseUrl: 'http://test-server:8000',
        client: mockClient,
      );

      expect(
        () => apiService.inspectTier0(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          filename: 'document.pdf',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(400))
              .having(
                (e) => e.message,
                'message',
                contains('Invalid file type'),
              ),
        ),
      );
    });
  });
}
