import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../landing_page.dart';
import '../models/audit_models.dart';
import '../theme/inquestor_theme.dart';
import '../widgets/inquestor_background.dart';

/// Final Forensic Evidence Report Page (Page 4).
/// Displays verdict, discrepancy breakdown, audit checklist, and raw agent evidence.
class FinalReportPage extends StatefulWidget {
  final VerificationResponse? responseOverride;
  final ExtractedProductClaims? claimsOverride;
  final Map<String, dynamic>? tier0Override;

  const FinalReportPage({
    super.key,
    this.responseOverride,
    this.claimsOverride,
    this.tier0Override,
  });

  @override
  State<FinalReportPage> createState() => _FinalReportPageState();
}

class _FinalReportPageState extends State<FinalReportPage> {
  bool _showRawEvidence = false;
  bool _copiedToClipboard = false;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final VerificationResponse response = widget.responseOverride ??
        (args?['verification_response'] != null
            ? VerificationResponse.fromJson(
                args!['verification_response'] as Map<String, dynamic>)
            : const VerificationResponse(
                verdict: VerdictStatus.unableToVerify,
                category: InquestCategory.electronics,
                summaryBanner: 'No verification record supplied.',
              ));

    final ExtractedProductClaims? claims = widget.claimsOverride ??
        (args?['claims'] != null
            ? ExtractedProductClaims.fromJson(args!['claims'] as Map<String, dynamic>)
            : null);

    final isVerified = response.verdict == VerdictStatus.verifiedMatch;
    final isSuspicious = response.verdict == VerdictStatus.suspicious;

    final Color statusColor = isVerified
        ? InquestorColors.forestGreen
        : (isSuspicious ? InquestorColors.coralRed : InquestorColors.amber);

    final String statusIconText = isVerified ? '✓' : (isSuspicious ? '✗' : '⚠');

    return InquestorBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6).withValues(alpha: 0.85),
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
            constraints: const BoxConstraints(maxWidth: 620),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InquestorBrandHeader(
                  onTap: () => Navigator.of(context).pushReplacementNamed('/'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/tier0'),
                  icon: const Icon(
                    Icons.refresh_outlined,
                    size: 15,
                    color: InquestorColors.graphite,
                  ),
                  label: const Text(
                    'New Inspection',
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
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Breadcrumb
                Row(
                  children: [
                    const Text(
                      'TIER 0',
                      style: TextStyle(
                        color: InquestorColors.softSlate,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 13, color: InquestorColors.softSlate),
                    const SizedBox(width: 6),
                    const Text(
                      'PAGE 2 (STAGING)',
                      style: TextStyle(
                        color: InquestorColors.softSlate,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 13, color: InquestorColors.softSlate),
                    const SizedBox(width: 6),
                    Text(
                      'FINAL EVIDENCE REPORT',
                      style: TextStyle(
                        color: InquestorColors.graphite.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Verdict Banner Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusIconText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  response.verdict,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            response.category.toUpperCase(),
                            style: const TextStyle(
                              color: InquestorColors.softSlate,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        claims != null && claims.brandName != null
                            ? '${claims.brandName} · ${claims.modelOrDrugName ?? "Forensic Review"}'
                            : 'Forensic Inquest Assessment',
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        response.summaryBanner,
                        style: const TextStyle(
                          color: InquestorColors.softSlate,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Forensic Discrepancy Card (if present)
                if (response.forensicDiscrepancy != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: InquestorColors.pureWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: InquestorColors.coralRed.withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: InquestorColors.coralRed),
                            SizedBox(width: 8),
                            Text(
                              'FORENSIC DISCREPANCY RECORDED',
                              style: TextStyle(
                                color: InquestorColors.coralRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDiscrepancyRow(
                          'Contradiction Field',
                          response.forensicDiscrepancy!['field']?.toString() ?? 'Model / Serial Mismatch',
                        ),
                        const Divider(height: 16),
                        _buildDiscrepancyRow(
                          'Packaging Claim',
                          response.forensicDiscrepancy!['packaging_claim']?.toString() ?? 'Unknown Claim',
                        ),
                        const Divider(height: 16),
                        _buildDiscrepancyRow(
                          'Authoritative Record',
                          response.forensicDiscrepancy!['official_record']?.toString() ?? 'Mismatch',
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Master Audit Checklist Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                        'MULTI-TIER AUDIT TRAIL',
                        style: TextStyle(
                          color: InquestorColors.graphiteSubtle,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (response.checklist.isEmpty)
                        const Text(
                          'No audit items reported.',
                          style: TextStyle(color: InquestorColors.softSlate, fontSize: 12),
                        )
                      else
                        ...response.checklist.map((item) => _buildChecklistRow(item)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Raw Agent Evidence Toggle
                Container(
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showRawEvidence = !_showRawEvidence;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.terminal_outlined,
                                    size: 16,
                                    color: InquestorColors.graphite,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _showRawEvidence
                                        ? 'Hide Raw Agent Evidence'
                                        : 'View Raw Agent Evidence (TinyFish Payload)',
                                    style: const TextStyle(
                                      color: InquestorColors.graphite,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _showRawEvidence
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 18,
                                color: InquestorColors.softSlate,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showRawEvidence) ...[
                        const Divider(height: 1),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: const Color(0xFF1E2124),
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(response.rawEvidence ?? {}),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFD4D4D4),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Bottom Action Buttons
                ElevatedButton(
                  onPressed: () {
                    final reportText = StringBuffer()
                      ..writeln('INQUESTOR FORENSIC EVIDENCE REPORT')
                      ..writeln('Verdict: ${response.verdict}')
                      ..writeln('Category: ${response.category}')
                      ..writeln('Summary: ${response.summaryBanner}')
                      ..writeln('\nAudit Trail:');
                    for (final item in response.checklist) {
                      reportText.writeln(
                          '[${item.passed ? "PASS" : "FAIL"}] (${item.tier}) ${item.name}: ${item.details}');
                    }
                    Clipboard.setData(ClipboardData(text: reportText.toString()));
                    setState(() {
                      _copiedToClipboard = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forensic Report copied to clipboard.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: InquestorColors.graphite,
                    foregroundColor: InquestorColors.pureWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    _copiedToClipboard ? '✓ REPORT COPIED TO CLIPBOARD' : 'COPY FORENSIC REPORT TO CLIPBOARD',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/tier0'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: InquestorColors.graphite,
                    side: const BorderSide(color: InquestorColors.hairlineBorder, width: 1.0),
                    backgroundColor: InquestorColors.pureWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'START NEW PRODUCT INTAKE',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDiscrepancyRow(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? InquestorColors.coralRed : InquestorColors.graphite,
            fontSize: 12.5,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistRow(AuditCheckItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: item.passed
                  ? InquestorColors.forestGreen.withValues(alpha: 0.1)
                  : InquestorColors.coralRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              item.passed ? Icons.check : Icons.close,
              size: 13,
              color: item.passed ? InquestorColors.forestGreen : InquestorColors.coralRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: InquestorColors.porcelain,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: InquestorColors.hairlineBorder),
                      ),
                      child: Text(
                        item.tier,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: InquestorColors.softSlate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.details,
                  style: const TextStyle(
                    color: InquestorColors.softSlate,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
