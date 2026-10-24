import 'package:flutter/material.dart';
import '../landing_page.dart';

/// Destination screen for Tier 1 & 2 (Page 2: Packaging OCR & Deterministic Rules).
/// Displays passed metadata from Tier 0 inspection state machine.
class Page2PlaceholderPage extends StatelessWidget {
  const Page2PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String detectedBrand = args?['detected_brand'] as String? ?? 'Unknown Brand';
    final String detectedCategory = args?['detected_category'] as String? ?? 'General';
    final bool isLogoValid = args?['is_logo_valid'] as bool? ?? false;
    final bool bypassed = args?['bypassed'] as bool? ?? false;

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
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InquestorBrandHeader(
                  onTap: () => Navigator.of(context).pushReplacementNamed('/'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 15,
                    color: InquestorColors.graphite,
                  ),
                  label: const Text(
                    'Retake Intake',
                    style: TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Breadcrumb
                Row(
                  children: [
                    const Text(
                      'TIER 0 VERIFIED',
                      style: TextStyle(
                        color: InquestorColors.softSlate,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: InquestorColors.softSlate,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PAGE 2: PACKAGING OCR & GS1 RULES',
                      style: TextStyle(
                        color: InquestorColors.graphite.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Intake Summary Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'INTAKE HAND-OFF METADATA',
                            style: TextStyle(
                              color: InquestorColors.softSlate,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: bypassed
                                  ? InquestorColors.coralRed.withValues(alpha: 0.08)
                                  : InquestorColors.forestGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: bypassed
                                    ? InquestorColors.coralRed.withValues(alpha: 0.3)
                                    : InquestorColors.forestGreen.withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              bypassed ? 'MANUALLY BYPASSED' : 'TIER 0 PASSED',
                              style: TextStyle(
                                color: bypassed
                                    ? InquestorColors.coralRed
                                    : InquestorColors.forestGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        detectedBrand,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${detectedCategory.toUpperCase()} · Logo Valid: $isLogoValid',
                        style: const TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Step 2 Instructions Card
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STEP 2: PACKAGING EVIDENCE CAPTURE',
                        style: TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Capture Packaging Label & Barcode',
                        style: TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Position the product box or blister pack to capture serial numbers, batch lot codes, and GS1 2D DataMatrix barcode elements for deterministic rule validation.',
                        style: TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.qr_code_scanner, size: 16),
                        label: const Text('Scan Packaging Barcode / OCR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: InquestorColors.graphite,
                          side: const BorderSide(
                            color: InquestorColors.hairlineBorder,
                            width: 1.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
