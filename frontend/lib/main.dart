import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'screens/audit_staging_page.dart';
import 'screens/final_report_page.dart';
import 'screens/tier0_inspection_page.dart';
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
        '/tier0': (context) => const Tier0InspectionPage(),
        '/page2': (context) => const AuditStagingPage(),
        '/report': (context) => const FinalReportPage(),
      },
    );
  }
}
