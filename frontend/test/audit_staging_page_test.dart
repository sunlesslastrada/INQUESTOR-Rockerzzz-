import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inquestor/models/audit_models.dart';
import 'package:inquestor/screens/audit_staging_page.dart';
import 'package:inquestor/services/audit_service.dart';
import 'package:inquestor/theme/inquestor_theme.dart';

class MockAuditService extends AuditService {
  final Future<ExtractedProductClaims> Function()? onExtract;
  final Future<VerificationResponse> Function(VerificationRequest req)? onVerify;

  MockAuditService({this.onExtract, this.onVerify});

  @override
  Future<ExtractedProductClaims> extractClaims({
    required String category,
    required dynamic packagingBytes,
    required String packagingFilename,
    required dynamic barcodeBytes,
    required String barcodeFilename,
    dynamic qrBytes,
    String? qrFilename,
    bool mockFallback = true,
    String? fallbackPreset,
  }) async {
    if (onExtract != null) return onExtract!();
    return const ExtractedProductClaims(
      category: InquestCategory.electronics,
      brandName: 'Sony',
      modelOrDrugName: 'WH-1000XM5',
      barcodeGtin: '0027242923508',
      serialOrBatchNumber: '5281902',
    );
  }

  @override
  Future<VerificationResponse> verifyProduct(VerificationRequest request) async {
    if (onVerify != null) return onVerify!(request);
    return const VerificationResponse(
      verdict: VerdictStatus.verifiedMatch,
      category: InquestCategory.electronics,
      summaryBanner: 'Information Match Confirmed.',
      checklist: [
        AuditCheckItem(
          tier: 'Tier-2',
          name: 'GS1 Checksum',
          passed: true,
          details: 'Valid check digit',
        ),
      ],
    );
  }
}

void main() {
  group('LocalDeterministicEvaluator Unit Tests', () {
    test('Calculates valid GS1 Modulo-10 checksum', () {
      const claims = ExtractedProductClaims(
        category: InquestCategory.electronics,
        barcodeGtin: '0027242923508',
      );
      final results = LocalDeterministicEvaluator.evaluate(claims);
      final gtinCheck = results.firstWhere((r) => r.name.contains('GS1'));
      expect(gtinCheck.passed, isTrue);
    });

    test('Flags invalid GS1 Modulo-10 checksum', () {
      const claims = ExtractedProductClaims(
        category: InquestCategory.electronics,
        barcodeGtin: '0027242923509', // Wrong check digit (9 instead of 8)
      );
      final results = LocalDeterministicEvaluator.evaluate(claims);
      final gtinCheck = results.firstWhere((r) => r.name.contains('GS1'));
      expect(gtinCheck.passed, isFalse);
    });

    test('Validates Sony 7-digit serial pattern', () {
      const claims = ExtractedProductClaims(
        category: InquestCategory.electronics,
        brandName: 'Sony',
        serialOrBatchNumber: '5281902',
      );
      final results = LocalDeterministicEvaluator.evaluate(claims);
      final serialCheck = results.firstWhere((r) => r.name.contains('Syntax'));
      expect(serialCheck.passed, isTrue);
    });
  });

  group('AuditStagingPage UI & State Machine', () {
    testWidgets('Renders Category chips, 5 Demo Presets, and 3 Viewfinder slots',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          home: const AuditStagingPage(),
        ),
      );

      // Verify Brand header
      expect(find.text('INQUESTOR'), findsOneWidget);
      expect(find.text('STAGE 2: INTAKE & FORENSIC GATEKEEPER'), findsOneWidget);

      // Category Chips
      expect(find.text('🎧 Electronics'), findsOneWidget);
      expect(find.text('💊 Medicine'), findsOneWidget);

      // 5 Demo Presets
      expect(find.text('1. Cloned Headset'), findsOneWidget);
      expect(find.text('2. Recalled Batch'), findsOneWidget);
      expect(find.text('3. Generic Unverified'), findsOneWidget);
      expect(find.text('4. Verified Medicine'), findsOneWidget);
      expect(find.text('5. Verified Electronics'), findsOneWidget);

      // 3 Slots
      expect(find.text('Slot 1: Packaging Text Label / Foil'), findsOneWidget);
      expect(find.text('Slot 2: Barcode / GS1 DataMatrix'), findsOneWidget);
      expect(find.text('Slot 3: QR Verification Link'), findsOneWidget);
      expect(find.text('EXTRACT CLAIMS →'), findsOneWidget);
    });

    testWidgets('Tapping Demo Preset populates claims form and triggers live Tier-2 checks',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          home: const AuditStagingPage(),
        ),
      );

      // Tap 1-Tap Demo Preset: Cloned Headset
      await tester.tap(find.text('1. Cloned Headset'));
      await tester.pumpAndSettle();

      // Form is populated
      expect(find.text('HUMAN-IN-THE-LOOP CLAIM STAGING'), findsOneWidget);
      expect(find.text('WH-1000XM5 Wireless Headphones'), findsOneWidget);
      expect(find.text('5281902'), findsOneWidget);

      // Tier-2 Instant Local Analysis is rendered
      expect(find.text('TIER 2: DETERMINISTIC FAST-FAIL CHECKS'), findsOneWidget);
      expect(find.text('GS1 GTIN Modulo-10 Checksum'), findsOneWidget);

      // Inquest Button is present
      expect(find.text('🔍 RUN FORENSIC INQUEST'), findsOneWidget);
    });

    testWidgets('Tapping Run Forensic Inquest executes animated stepper and transitions to /report',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, dynamic>? pushedArgs;

      final mockService = MockAuditService(
        onVerify: (req) async {
          return const VerificationResponse(
            verdict: VerdictStatus.verifiedMatch,
            category: InquestCategory.electronics,
            summaryBanner: 'Information Match Confirmed.',
            checklist: [
              AuditCheckItem(
                tier: 'Tier-2',
                name: 'GS1 Checksum',
                passed: true,
                details: 'Valid check digit',
              ),
            ],
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: InquestorTheme.lightTheme,
          initialRoute: '/page2',
          routes: {
            '/page2': (context) => AuditStagingPage(serviceOverride: mockService),
            '/report': (context) {
              pushedArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return const Scaffold(body: Text('Report Destination Screen'));
            },
          },
        ),
      );

      // Select Demo Preset 5
      await tester.tap(find.text('5. Verified Electronics'));
      await tester.pumpAndSettle();

      // Tap Run Inquest
      await tester.tap(find.text('🔍 RUN FORENSIC INQUEST'));
      await tester.pump();

      // Verify Stepper is shown
      expect(find.text('TIER 3: LIVE FORENSIC AGENT INVESTIGATION'), findsOneWidget);

      // Advance timers through Step 1, Step 2, Step 3
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Successfully reached /report
      expect(find.text('Report Destination Screen'), findsOneWidget);
      expect(pushedArgs, isNotNull);
      expect(pushedArgs!['verification_response'], isNotNull);
    });
  });
}
