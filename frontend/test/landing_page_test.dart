import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inquestor/landing_page.dart';

void main() {
  testWidgets('LandingPage renders brand mark, headline, and pipeline sections', (tester) async {
    // Set desktop-like size
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool initiated = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: InquestorTheme.lightTheme,
        home: LandingPage(
          onInitiateInquest: () {
            initiated = true;
          },
        ),
      ),
    );

    // Verify Brand Mark, Wordmark, and Version
    expect(find.text('INQUESTOR'), findsOneWidget);
    expect(find.text('v.1.6.7'), findsOneWidget);
    expect(find.byType(InquestorBrandMark), findsNWidgets(2));

    // Verify Badge & Headlines
    expect(find.text('◈'), findsOneWidget);
    expect(find.text('Autonomous Forensic Product Verification'), findsOneWidget);
    expect(find.text('From Scan to Trust.'), findsOneWidget);
    expect(find.text("Don't just scan a product. Verify its evidence."), findsOneWidget);

    // Verify 3-Tier Pipeline
    expect(find.text('THE 3-TIER FORENSIC PIPELINE'), findsOneWidget);
    expect(find.text('Packaging Vision & Ingestion'), findsOneWidget);
    expect(find.text('Deterministic Rule Gatekeeper'), findsOneWidget);
    expect(find.text('Authoritative Ground Truth'), findsOneWidget);

    // Verify Industry Tracks
    expect(find.text('Consumer Electronics'), findsOneWidget);
    expect(find.text('Pharmaceuticals & Healthcare'), findsOneWidget);

    // Verify CTA tap
    final ctaButton = find.text('Initiate Product Inquest →');
    expect(ctaButton, findsOneWidget);
    await tester.tap(ctaButton);
    await tester.pumpAndSettle();

    expect(initiated, isTrue);
  });
}
