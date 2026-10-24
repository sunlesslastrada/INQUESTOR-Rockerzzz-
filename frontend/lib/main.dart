import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'theme/inquestor_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InquestorApp());
}

/// Root Application Widget for INQUESTOR.
class InquestorApp extends StatelessWidget {
  const InquestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INQUESTOR — Autonomous Forensic Product Verification',
      debugShowCheckedModeBanner: false,
      theme: InquestorTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/tier0': (context) => const Tier0PlaceholderPage(),
      },
    );
  }
}

/// Clean placeholder page for Tier 0 (Intake & Visual Anomaly Scanner)
/// Demonstrates the seamless navigation routing from the Landing Page CTA.
class Tier0PlaceholderPage extends StatelessWidget {
  const Tier0PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InquestorColors.porcelain,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: InquestorColors.porcelain,
            border: Border(
              bottom: BorderSide(
                color: InquestorColors.hairlineBorder,
                width: 1.0,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InquestorBrandHeader(
                onTap: () => Navigator.of(context).pushReplacementNamed('/'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: InquestorColors.graphite,
                ),
                label: const Text(
                  'Back to Landing',
                  style: TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                  backgroundColor: InquestorColors.pureWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: InquestorColors.pureWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: InquestorColors.hairlineBorder,
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: InquestorColors.porcelain,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: InquestorColors.hairlineBorder,
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 24,
                      color: InquestorColors.graphite,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TIER 0 & 1 INTAKE READY',
                    style: TextStyle(
                      color: InquestorColors.softSlate,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Visual Anomaly & Packaging Scanner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Route /tier0 connected successfully. Feed high-resolution product packaging photography or live camera feed to initiate vision inspection and OCR credential extraction.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: InquestorColors.softSlate,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
