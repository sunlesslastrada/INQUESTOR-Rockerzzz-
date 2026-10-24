import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inquestor/models/tier0_models.dart';
import 'package:inquestor/screens/tier0_inspection_page.dart';
import 'package:inquestor/services/api_service.dart';
import 'package:inquestor/services/tier0_service.dart';
import 'package:inquestor/theme/inquestor_theme.dart';

class TestMockTier0Service extends Tier0Service {
  final Future<Tier0Response> Function(Uint8List bytes, String filename)? onInspect;

  TestMockTier0Service({this.onInspect, super.baseUrl});

  @override
  Future<Tier0Response> inspectImage({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    if (onInspect != null) {
      return onInspect!(imageBytes, filename);
    }
    return Tier0Response.presetAuthentic;
  }
}

void main() {
  group('Tier0Response Serialization', () {
    test('Correctly parses valid JSON payload from backend', () {
      final json = {
        'is_logo_valid': true,
        'detected_brand': 'Sony',
        'detected_category': 'electronics',
        'confidence': 0.99,
        'anomalies_detected': <String>[],
        'reasoning': 'Valid OEM emblem.',
        'can_proceed': true,
      };

      final response = Tier0Response.fromJson(json);
      expect(response.isLogoValid, isTrue);
      expect(response.detectedBrand, equals('Sony'));
      expect(response.detectedCategory, equals('electronics'));
      expect(response.confidence, equals(0.99));
      expect(response.anomaliesDetected, isEmpty);
      expect(response.reasoning, equals('Valid OEM emblem.'));
      expect(response.canProceed, isTrue);
    });

    test('Correctly handles default values for missing or null JSON fields', () {
      final json = <String, dynamic>{};
      final response = Tier0Response.fromJson(json);

      expect(response.isLogoValid, isFalse);
      expect(response.detectedBrand, equals('Unknown'));
      expect(response.detectedCategory, equals('unsupported'));
      expect(response.confidence, equals(0.0));
      expect(response.anomaliesDetected, isEmpty);
      expect(response.reasoning, isEmpty);
      expect(response.canProceed, isFalse);
    });
  });

  group('Tier0InspectionPage UI & State Machine', () {
    testWidgets('Renders viewfinder, triggers, and demo presets', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          home: const Tier0InspectionPage(),
        ),
      );

      expect(find.text('INQUESTOR'), findsOneWidget);
      expect(find.text('Landing Page'), findsOneWidget);
      expect(find.text('TIER 0'), findsOneWidget);

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);

      expect(find.text('DEMO PRESET TESTBENCH'), findsOneWidget);
      expect(find.text('Reset Scanner'), findsOneWidget);
      expect(find.text('✓ HP Laptop (Authentic)'), findsOneWidget);
      expect(find.text('✗ "Abibas" (Spoofed Logo)'), findsOneWidget);
      expect(find.text('⊘ Nike Sneaker (Out of Scope)'), findsOneWidget);
    });

    testWidgets('Authentic Result automatically navigates to /page2 after 1.2s delay',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, dynamic>? pushedArgs;

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          initialRoute: '/tier0',
          routes: {
            '/tier0': (context) => const Tier0InspectionPage(),
            '/page2': (context) {
              pushedArgs = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              return const Scaffold(body: Text('Destination Page 2'));
            },
          },
        ),
      );

      // Tap Authentic HP Laptop preset
      await tester.tap(find.text('✓ HP Laptop (Authentic)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      // Verify State A Verified Card is rendered
      expect(find.text('VERIFIED · HP'), findsOneWidget);
      expect(find.text('98% Confidence'), findsOneWidget);
      expect(find.text('Trademark Geometry Validated'), findsOneWidget);

      // Verify user stays on page (no auto redirection away)
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Destination Page 2'), findsNothing);

      // Verify manual progression CTA
      expect(find.text('RETAKE / SCAN ANOTHER'), findsOneWidget);
      final proceedButton = find.text('PROCEED TO NEXT STAGE →');
      expect(proceedButton, findsOneWidget);
      await tester.tap(proceedButton);
      await tester.pumpAndSettle();

      // Destination screen reached
      expect(find.text('Destination Page 2'), findsOneWidget);
      expect(pushedArgs, isNotNull);
      expect(pushedArgs!['detected_brand'], equals('HP'));
      expect(pushedArgs!['detected_category'], equals('electronics'));
      expect(pushedArgs!['is_logo_valid'], isTrue);
      expect(pushedArgs!['bypassed'], isFalse);
    });

    testWidgets('Counterfeit Result halts auto-navigation and provides manual bypass',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, dynamic>? pushedArgs;

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          initialRoute: '/tier0',
          routes: {
            '/tier0': (context) => const Tier0InspectionPage(),
            '/page2': (context) {
              pushedArgs = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              return const Scaffold(body: Text('Destination Page 2'));
            },
          },
        ),
      );

      // Tap Counterfeit Preset
      await tester.tap(find.text('✗ "Abibas" (Spoofed Logo)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify Red Discrepancy Card
      expect(find.text('TIER 0: COUNTERFEIT ANOMALY DETECTED'), findsOneWidget);
      expect(find.text('Abibas (Spoof of Adidas)'), findsOneWidget);
      expect(find.text('94% Confidence'), findsOneWidget);
      expect(find.text('FORENSIC ANOMALY BREAKDOWN'), findsOneWidget);
      expect(
        find.text("Trademark typography misspelling ('Abibas' instead of 'Adidas')"),
        findsOneWidget,
      );

      // Ensure NO automatic route transition happens after 2 seconds
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Destination Page 2'), findsNothing);

      // Verify Sticky Bottom CTAs
      expect(find.text('MANUAL BYPASS & PROCEED →'), findsOneWidget);
      expect(find.text('RETAKE / UPLOAD NEW IMAGE'), findsOneWidget);

      // Tap Manual Bypass CTA
      await tester.tap(find.text('MANUAL BYPASS & PROCEED →'));
      await tester.pumpAndSettle();

      expect(find.text('Destination Page 2'), findsOneWidget);
      expect(pushedArgs, isNotNull);
      expect(pushedArgs!['bypassed'], isTrue);
      expect(pushedArgs!['is_logo_valid'], isFalse);
    });

    testWidgets('Out-of-Scope strictly blocks bypass to /page2', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          initialRoute: '/tier0',
          routes: {
            '/tier0': (context) => const Tier0InspectionPage(),
            '/': (context) => const Scaffold(body: Text('Landing Page Home')),
            '/page2': (context) => const Scaffold(body: Text('Destination Page 2')),
          },
        ),
      );

      // Tap Out of Scope Preset
      await tester.tap(find.text('⊘ Nike Sneaker (Out of Scope)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Verify State C Card
      expect(find.text('CATEGORY OUT OF SCOPE'), findsOneWidget);
      expect(find.text('Category: footwear'), findsOneWidget);

      // Strict Guardrail: NO manual bypass button
      expect(find.text('MANUAL BYPASS & PROCEED →'), findsNothing);
      expect(find.text('PROCEED TO PAGE 2 NOW →'), findsNothing);

      // Verify CTAs
      expect(find.text('EXIT / RETURN HOME'), findsOneWidget);
      expect(find.text('SCAN DIFFERENT PRODUCT'), findsOneWidget);

      // Tap Exit / Return Home
      await tester.tap(find.text('EXIT / RETURN HOME'));
      await tester.pumpAndSettle();
      expect(find.text('Landing Page Home'), findsOneWidget);
    });

    testWidgets('Displays in-place error card when backend call fails', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final failingService = TestMockTier0Service(
        onInspect: (bytes, filename) async {
          throw const ApiException('Backend returned HTTP 500', statusCode: 500);
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          home: Tier0InspectionPage(serviceOverride: failingService),
        ),
      );

      // Trigger photo/upload via test helper method
      final state = tester.state<Tier0InspectionPageState>(
        find.byType(Tier0InspectionPage),
      );

      final testPngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      await state.triggerInspectionForTesting(
        testPngBytes,
        'test_failure.png',
      );
      await tester.pumpAndSettle();

      expect(find.text('BACKEND INSPECTION FAILED'), findsOneWidget);
      expect(find.text('Backend returned HTTP 500'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);
      expect(find.text('DISMISS / RESET'), findsOneWidget);
    });
  });
}
