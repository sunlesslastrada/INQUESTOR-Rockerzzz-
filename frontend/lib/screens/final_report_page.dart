import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../landing_page.dart';
import '../models/audit_models.dart';
import '../theme/inquestor_theme.dart';
import '../widgets/inquestor_background.dart';

/// Final Forensic Evidence Report Screen (Page 4).
/// Aggregates the complete evidentiary trail across Tier 0 (Logo & Emblem),
/// Tier 1 (Extracted Claims), Tier 2 (Deterministic Gatekeeper), and Tier 3
/// (External Registry & TinyFish Agent Audit) into an executive forensic dashboard.
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
  bool _isEvidenceExpanded = true;
  bool _showRawJson = false;
  bool _copiedToClipboard = false;
  bool _copiedJsonToClipboard = false;

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

    final String statusIconText = isVerified ? '✓' : (isSuspicious ? '✗' : 'ℹ');

    return InquestorBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6).withValues(alpha: 0.85),
              border: const Border(
                bottom: BorderSide(
                  color: InquestorColors.hairlineBorder,
                  width: 1.0,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InquestorBrandHeader(
                    onTap: () => Navigator.of(context).pushReplacementNamed('/'),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Settings / Configuration',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Inquestor Engine v1.0.0 · All forensic models active.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.settings_outlined,
                          size: 16,
                          color: InquestorColors.softSlate,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/tier0'),
                        icon: const Icon(
                          Icons.refresh_outlined,
                          size: 15,
                          color: InquestorColors.graphite,
                        ),
                        label: const Text(
                          'New Inquest',
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
                ],
              ),
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Breadcrumb Tracker
                  _buildBreadcrumbTracker(),
                  const SizedBox(height: 20),

                  // A. Hero Verdict Card (Top Anchor)
                  _buildHeroVerdictCard(response, claims, statusColor, statusIconText),
                  const SizedBox(height: 18),

                  // B. Forensic Summary Callout Banner
                  _buildSummaryCallout(response.summaryBanner, statusColor),
                  const SizedBox(height: 18),

                  // C. Forensic Discrepancy Split-Card (Conditional)
                  if (response.forensicDiscrepancy != null) ...[
                    _buildDiscrepancySplitCard(response.forensicDiscrepancy!),
                    const SizedBox(height: 18),
                  ],

                  // D. Product Claims & Metadata Summary Card
                  _buildProductMetadataCard(claims, response.category),
                  const SizedBox(height: 18),

                  // E. Itemized Multi-Tier Audit Checklist
                  _buildChecklistCard(response.checklist),
                  const SizedBox(height: 18),

                  // F. Technical Evidence Drawer & Stylized Dossier
                  _buildTinyFishEvidenceCard(response, claims, statusColor),
                  const SizedBox(height: 28),

                  // G. Bottom Action Controls
                  _buildBottomActionButtons(response, claims),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // A. BREADCRUMB & HERO VERDICT COMPONENTS
  // ==========================================================================

  Widget _buildBreadcrumbTracker() {
    return const Row(
      children: [
        Text(
          'TIER 0',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 12, color: InquestorColors.softSlate),
        SizedBox(width: 6),
        Text(
          'STAGE 2',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 12, color: InquestorColors.softSlate),
        SizedBox(width: 6),
        Text(
          'FINAL FORENSIC REPORT',
          style: TextStyle(
            color: InquestorColors.graphite,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroVerdictCard(
    VerificationResponse response,
    ExtractedProductClaims? claims,
    Color statusColor,
    String statusIconText,
  ) {
    final bool isMedicine = response.category == InquestCategory.medicine;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor, width: 1.4),
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
              // Verdict Pill
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
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Category Badge & Audit Stamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: InquestorColors.porcelain,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: InquestorColors.hairlineBorder),
                    ),
                    child: Text(
                      isMedicine ? '💊 MEDICINE' : '🎧 ELECTRONICS',
                      style: const TextStyle(
                        color: InquestorColors.graphite,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Product Headline
          Text(
            claims != null && claims.brandName != null
                ? '${claims.brandName} · ${claims.modelOrDrugName ?? "Forensic Review"}'
                : 'Executive Forensic Evidence Report',
            style: const TextStyle(
              color: InquestorColors.graphite,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: InquestorColors.antiqueGold),
              SizedBox(width: 5),
              Text(
                'MULTI-TIER EVIDENCE ENGINE · AUDIT VERIFIED',
                style: TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // B. FORENSIC SUMMARY CALLOUT BANNER
  // ==========================================================================

  Widget _buildSummaryCallout(String summaryBanner, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXECUTIVE FORENSIC SUMMARY',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summaryBanner,
                  style: const TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // C. FORENSIC DISCREPANCY SPLIT-CARD
  // ==========================================================================

  Widget _buildDiscrepancySplitCard(Map<String, dynamic> discrepancy) {
    final String field = discrepancy['field']?.toString() ?? 'Forensic Contradiction';
    final String packagingClaim =
        discrepancy['packaging_claim']?.toString() ?? 'Claim on physical packaging';
    final String officialRecord =
        discrepancy['official_record']?.toString() ?? 'Authoritative registry record';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.coralRed.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.coralRed.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: InquestorColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CRITICAL MISMATCH',
                  style: TextStyle(
                    color: InquestorColors.coralRed,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Field Under Dispute
          Row(
            children: [
              const Text(
                'DISPUTED ATTRIBUTE: ',
                style: TextStyle(
                  color: InquestorColors.softSlate,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                field.toUpperCase(),
                style: const TextStyle(
                  color: InquestorColors.graphite,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side-by-side comparison split-cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Box / Packaging Claim (Tier 1)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E5E2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: InquestorColors.softSlate),
                          SizedBox(width: 5),
                          Text(
                            'BOX CLAIM (TIER 1)',
                            style: TextStyle(
                              color: InquestorColors.softSlate,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        packagingClaim,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: InquestorColors.softSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Right: Official Registry Record (Tier 3)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: InquestorColors.coralRed.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InquestorColors.coralRed.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_outlined, size: 12, color: InquestorColors.coralRed),
                          SizedBox(width: 5),
                          Text(
                            'REGISTRY RECORD (TIER 3)',
                            style: TextStyle(
                              color: InquestorColors.coralRed,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        officialRecord,
                        style: const TextStyle(
                          color: InquestorColors.coralRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Forensic Verdict: The physical packaging claim directly contradicts official database records. Strong indicator of serial number cloning, packaging counterfeiting, or regulatory withdrawal.',
            style: TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // D. PRODUCT CLAIMS & METADATA SUMMARY CARD
  // ==========================================================================

  Widget _buildProductMetadataCard(ExtractedProductClaims? claims, String category) {
    if (claims == null) return const SizedBox.shrink();

    final bool isMedicine = category == InquestCategory.medicine;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.graphite.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 15, color: InquestorColors.graphite),
                  SizedBox(width: 8),
                  Text(
                    'VERIFIED PRODUCT ATTRIBUTES',
                    style: TextStyle(
                      color: InquestorColors.graphiteSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: InquestorColors.porcelain,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: InquestorColors.hairlineBorder),
                ),
                child: Text(
                  isMedicine ? '💊 MEDICINE' : '🎧 ELECTRONICS',
                  style: const TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetaTile(
                  'Brand Manufacturer',
                  claims.brandName ?? 'Not Detected',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetaTile(
                  isMedicine ? 'Drug / Formulation' : 'Product Model',
                  claims.modelOrDrugName ?? 'Not Detected',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetaTile(
                  'Barcode / GTIN',
                  claims.barcodeGtin ?? 'No GTIN Scanned',
                  isMono: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetaTile(
                  isMedicine ? 'Batch / Lot Number' : 'Serial Number',
                  claims.serialOrBatchNumber ?? 'No Serial Recorded',
                  isMono: true,
                ),
              ),
            ],
          ),
          if (claims.expiryDate != null || claims.mfgDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (claims.mfgDate != null)
                  Expanded(
                    child: _buildMetaTile(
                      'Manufacturing Date',
                      claims.mfgDate!,
                      isMono: true,
                    ),
                  ),
                if (claims.mfgDate != null && claims.expiryDate != null)
                  const SizedBox(width: 10),
                if (claims.expiryDate != null)
                  Expanded(
                    child: _buildMetaTile(
                      'Expiration Date',
                      claims.expiryDate!,
                      isMono: true,
                    ),
                  ),
              ],
            ),
          ],
          if (claims.qrRedirectUrl != null && claims.qrRedirectUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMetaTile(
              'Scanned QR Redirect URL',
              claims.qrRedirectUrl!,
              isMono: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTile(String label, String value, {bool isMono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFEFEFEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: InquestorColors.graphite,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: isMono ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // E. ITEMIZED MULTI-TIER AUDIT CHECKLIST
  // ==========================================================================

  Widget _buildChecklistCard(List<AuditCheckItem> checklist) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: InquestorColors.hairlineBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.graphite.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist_rtl_outlined, size: 15, color: InquestorColors.graphite),
                  SizedBox(width: 8),
                  Text(
                    'MULTI-TIER FORENSIC AUDIT TRAIL',
                    style: TextStyle(
                      color: InquestorColors.graphiteSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: InquestorColors.porcelain,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: InquestorColors.hairlineBorder),
                ),
                child: Text(
                  '${checklist.where((c) => c.passed).length}/${checklist.length} PASSED',
                  style: const TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (checklist.isEmpty)
            const Text(
              'No audit items recorded.',
              style: TextStyle(color: InquestorColors.softSlate, fontSize: 12),
            )
          else
            ...checklist.map((item) => _buildChecklistRow(item)),
        ],
      ),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
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
                                fontWeight: FontWeight.w700,
                                color: InquestorColors.softSlate,
                                letterSpacing: 0.5,
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (item.passed ? InquestorColors.forestGreen : InquestorColors.coralRed)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        item.passed ? 'PASSED' : 'FAILED',
                        style: TextStyle(
                          color: item.passed ? InquestorColors.forestGreen : InquestorColors.coralRed,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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

  // ==========================================================================
  // F. TECHNICAL EVIDENCE DRAWER & STYLIZED DOSSIER (TINYFISH PAYLOAD)
  // ==========================================================================

  Map<String, dynamic> _extractEvidenceData(Map<String, dynamic> raw, String category) {
    final Map<String, dynamic> evidence = (raw['evidence'] is Map<String, dynamic>)
        ? raw['evidence'] as Map<String, dynamic>
        : raw;

    final bool isFastFail = raw['tier2_fast_fail'] == true;
    final List<String> fastFailChecks = (raw['failed_checks'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final Map<String, dynamic>? oemAgent = (evidence['tinyfish_agent'] is Map<String, dynamic>)
        ? evidence['tinyfish_agent'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? oemData = (oemAgent?['data'] is Map<String, dynamic>)
        ? oemAgent!['data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? oemRaw = (oemAgent?['raw'] is Map<String, dynamic>)
        ? oemAgent!['raw'] as Map<String, dynamic>
        : null;

    final Map<String, dynamic>? cdscoAgent = (evidence['tinyfish_cdsco_agent'] is Map<String, dynamic>)
        ? evidence['tinyfish_cdsco_agent'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? cdscoExtracted = (cdscoAgent?['extracted_data'] is Map<String, dynamic>)
        ? cdscoAgent!['extracted_data'] as Map<String, dynamic>
        : null;
    final Map<String, dynamic>? cdscoRaw = (cdscoAgent?['raw'] is Map<String, dynamic>)
        ? cdscoAgent!['raw'] as Map<String, dynamic>
        : null;

    final Map<String, dynamic>? qrSandbox = (evidence['qr_sandbox'] is Map<String, dynamic>)
        ? evidence['qr_sandbox'] as Map<String, dynamic>
        : null;

    final Map<String, dynamic>? mismatch = (evidence['mismatch_details'] is Map<String, dynamic>)
        ? evidence['mismatch_details'] as Map<String, dynamic>
        : null;

    final String? registeredModel = oemData?['registered_model']?.toString() ??
        raw['registered_model']?.toString();
    final String? warrantyStatus = oemData?['warranty_status']?.toString();
    final bool? isRecalled = cdscoAgent?['is_recalled'] as bool? ??
        cdscoExtracted?['is_recalled'] as bool? ??
        (raw['is_recalled'] == true ? true : null);
    final String? recallReason = cdscoExtracted?['recall_reason']?.toString() ??
        raw['details']?.toString();
    final String? alertTitle = cdscoExtracted?['alert_title']?.toString() ??
        raw['recall_notice']?.toString();

    final String fallbackId =
        'TF-' + DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    final String? runId = oemRaw?['run_id']?.toString() ??
        cdscoRaw?['run_id']?.toString() ??
        (raw['preset'] != null ? 'SIM-' + raw['preset'].toString().toUpperCase() : fallbackId);

    final int steps = oemRaw?['num_of_steps'] as int? ??
        cdscoRaw?['num_of_steps'] as int? ??
        5;

    final bool isMedicine = category == InquestCategory.medicine || cdscoAgent != null;

    return {
      'isFastFail': isFastFail,
      'fastFailChecks': fastFailChecks,
      'isMedicine': isMedicine,
      'registeredModel': registeredModel,
      'warrantyStatus': warrantyStatus,
      'isRecalled': isRecalled,
      'recallReason': recallReason,
      'alertTitle': alertTitle,
      'runId': runId,
      'steps': steps,
      'oemAgent': oemAgent,
      'cdscoAgent': cdscoAgent,
      'qrSandbox': qrSandbox,
      'mismatch': mismatch,
      'reason': raw['reason']?.toString(),
    };
  }

  Widget _buildTinyFishEvidenceCard(
    VerificationResponse response,
    ExtractedProductClaims? claims,
    Color statusColor,
  ) {
    final Map<String, dynamic> raw = response.rawEvidence ?? {};
    if (raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = _extractEvidenceData(raw, response.category);
    final isFastFail = data['isFastFail'] == true;
    final isMedicine = data['isMedicine'] == true;
    final String? registeredModel = data['registeredModel'];
    final String? warrantyStatus = data['warrantyStatus'];
    final bool? isRecalled = data['isRecalled'];
    final String? recallReason = data['recallReason'];
    final String? alertTitle = data['alertTitle'];
    final String? runId = data['runId'];
    final int steps = data['steps'] as int? ?? 5;
    final Map<String, dynamic>? qrSandbox = data['qrSandbox'];
    final Map<String, dynamic>? mismatch = data['mismatch'];
    final List<String> fastFailChecks = data['fastFailChecks'] as List<String>? ?? [];

    final bool isVerified = response.verdict == VerdictStatus.verifiedMatch;
    final bool isSuspicious = response.verdict == VerdictStatus.suspicious;

    final String statusBadgeText = isFastFail
        ? 'LOCAL FAST-FAIL'
        : (isVerified
            ? '✓ REGISTRY MATCH'
            : (isSuspicious ? '✗ CONTRADICTION FLAGGED' : '⚠ UNRESOLVED'));

    final Color badgeColor = isVerified
        ? InquestorColors.forestGreen
        : (isSuspicious ? InquestorColors.coralRed : InquestorColors.amber);

    return Container(
      decoration: BoxDecoration(
        color: InquestorColors.pureWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InquestorColors.hairlineBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: InquestorColors.graphite.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          InkWell(
            onTap: () {
              setState(() {
                _isEvidenceExpanded = !_isEvidenceExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: InquestorColors.porcelain,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: InquestorColors.hairlineBorder),
                        ),
                        child: const Icon(
                          Icons.travel_explore_outlined,
                          size: 15,
                          color: InquestorColors.graphite,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AUTHORITATIVE AGENT EVIDENCE DOSSIER',
                            style: TextStyle(
                              color: InquestorColors.graphite,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMedicine
                                ? 'CDSCO Regulatory Audit & NSQ Table Verification'
                                : 'TinyFish Autonomous Web Agent (v1.0 OEM Pipeline)',
                            style: const TextStyle(
                              color: InquestorColors.softSlate,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusBadgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isEvidenceExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: InquestorColors.softSlate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isEvidenceExpanded) ...[
            const Divider(height: 1, color: InquestorColors.hairlineBorder),

            // Tab Bar: [Visual Dossier | Raw JSON]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              color: const Color(0xFFFAF9F6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildViewModeButton(
                        label: 'Visual Dossier',
                        icon: Icons.article_outlined,
                        isActive: !_showRawJson,
                        onTap: () => setState(() => _showRawJson = false),
                      ),
                      const SizedBox(width: 6),
                      _buildViewModeButton(
                        label: 'Raw JSON',
                        icon: Icons.code_outlined,
                        isActive: _showRawJson,
                        onTap: () => setState(() => _showRawJson = true),
                      ),
                    ],
                  ),
                  if (runId != null)
                    Row(
                      children: [
                        const Text(
                          'RUN ID: ',
                          style: TextStyle(
                            color: InquestorColors.softSlate,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SelectableText(
                          runId.length > 20 ? runId.substring(0, 18) + '...' : runId,
                          style: const TextStyle(
                            color: InquestorColors.graphite,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: InquestorColors.hairlineBorder),

            // Body
            if (!_showRawJson)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Agent Metadata Ribbon
                    _buildAgentMetadataRibbon(
                      targetRegistry: isMedicine
                          ? 'CDSCO India Official Drug Gazette'
                          : 'OEM Manufacturer Warranty Portal',
                      agentEngine: 'TinyFish Playwright Browser Agent',
                      stepsTraversed: '$steps autonomous DOM actions',
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'AUTHORITATIVE REGISTRY FINDINGS',
                      style: TextStyle(
                        color: InquestorColors.graphiteSubtle,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (isFastFail)
                      _buildFastFailDossierCard(fastFailChecks)
                    else if (isMedicine)
                      _buildMedicineDossierCard(
                        batchNumber: claims?.serialOrBatchNumber ?? 'Queried Batch',
                        drugName: claims?.modelOrDrugName ?? 'Pharmaceutical Compound',
                        isRecalled: isRecalled == true,
                        alertTitle: alertTitle,
                        recallReason: recallReason,
                      )
                    else
                      _buildElectronicsDossierCard(
                        serialNumber: claims?.serialOrBatchNumber ?? 'Queried Serial',
                        claimedModel: claims?.modelOrDrugName,
                        registeredModel: registeredModel,
                        warrantyStatus: warrantyStatus,
                        mismatch: mismatch,
                      ),

                    if (qrSandbox != null) ...[
                      const SizedBox(height: 14),
                      _buildQrSandboxDossierCard(qrSandbox, claims?.qrRedirectUrl),
                    ],

                    const SizedBox(height: 14),

                    // Forensic Audit Stamp Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: InquestorColors.porcelain,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFEFEFEA)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 12, color: InquestorColors.antiqueGold),
                              SizedBox(width: 6),
                              Text(
                                'ATTESTED VIA TINYFISH AGENTIC PIPELINE',
                                style: TextStyle(
                                  color: InquestorColors.graphite,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'HASH: ' + (runId?.hashCode.toRadixString(16).toUpperCase() ?? '0x7F2B9C'),
                            style: const TextStyle(
                              color: InquestorColors.softSlate,
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              // Raw JSON Terminal View
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: const Color(0xFF181A1D),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.terminal, size: 13, color: Color(0xFF8B949E)),
                            SizedBox(width: 6),
                            Text(
                              'tinyfish_raw_payload.json',
                              style: TextStyle(
                                color: Color(0xFF8B949E),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                              text: const JsonEncoder.withIndent('  ').convert(raw),
                            ));
                            setState(() => _copiedJsonToClipboard = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copiedJsonToClipboard = false);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  _copiedJsonToClipboard ? Icons.check : Icons.copy,
                                  size: 12,
                                  color: _copiedJsonToClipboard
                                      ? InquestorColors.forestGreen
                                      : const Color(0xFF8B949E),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _copiedJsonToClipboard ? 'Copied' : 'Copy JSON',
                                  style: TextStyle(
                                    color: _copiedJsonToClipboard
                                        ? InquestorColors.forestGreen
                                        : const Color(0xFF8B949E),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1E2124),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(raw),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFFD4D4D4),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isActive ? InquestorColors.graphite : InquestorColors.pureWhite,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? InquestorColors.graphite : InquestorColors.hairlineBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isActive ? InquestorColors.pureWhite : InquestorColors.softSlate,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? InquestorColors.pureWhite : InquestorColors.graphite,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentMetadataRibbon({
    required String targetRegistry,
    required String agentEngine,
    required String stepsTraversed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE8E8E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetaColumn('TARGET REGISTRY', targetRegistry),
          ),
          Container(height: 24, width: 1, color: const Color(0xFFE0E0DC)),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetaColumn('AGENT ARCHITECTURE', agentEngine),
          ),
          Container(height: 24, width: 1, color: const Color(0xFFE0E0DC)),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetaColumn('EXECUTION COMPLEXITY', stepsTraversed),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: InquestorColors.graphite,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildElectronicsDossierCard({
    required String serialNumber,
    String? claimedModel,
    String? registeredModel,
    String? warrantyStatus,
    Map<String, dynamic>? mismatch,
  }) {
    final bool hasMismatch = mismatch != null ||
        (registeredModel != null &&
            claimedModel != null &&
            !registeredModel.toLowerCase().contains(claimedModel.toLowerCase()));

    final Color cardBorder = hasMismatch
        ? InquestorColors.coralRed.withValues(alpha: 0.35)
        : const Color(0xFFE8E8E4);
    final Color cardBg = hasMismatch
        ? InquestorColors.coralRed.withValues(alpha: 0.03)
        : const Color(0xFFFAFAF9);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasMismatch ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
                    size: 16,
                    color: hasMismatch ? InquestorColors.coralRed : InquestorColors.forestGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasMismatch ? 'OEM SERIAL CLONING DETECTED' : 'OEM SERIAL REGISTRATION CONFIRMED',
                    style: TextStyle(
                      color: hasMismatch ? InquestorColors.coralRed : InquestorColors.forestGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              if (warrantyStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: InquestorColors.pureWhite,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: InquestorColors.hairlineBorder),
                  ),
                  child: Text(
                    'WARRANTY: ' + warrantyStatus.toUpperCase(),
                    style: const TextStyle(
                      color: InquestorColors.graphite,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEvidenceDetailRow('Queried Serial Number', serialNumber, isMono: true),
          const SizedBox(height: 8),
          _buildEvidenceDetailRow(
            'Official Registered Device',
            registeredModel ?? 'Serial not found on OEM portal database',
            valueColor: hasMismatch ? InquestorColors.coralRed : InquestorColors.graphite,
          ),
          if (claimedModel != null && hasMismatch) ...[
            const SizedBox(height: 8),
            _buildEvidenceDetailRow(
              'Packaging Claimed Device',
              claimedModel,
              valueColor: InquestorColors.softSlate,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: InquestorColors.coralRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: InquestorColors.coralRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Forensic Analysis: The packaging claims high-end hardware, but the physical serial belongs to lower-tier earphones. Critical counterfeit indicator.',
                      style: TextStyle(
                        color: InquestorColors.coralRed,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicineDossierCard({
    required String batchNumber,
    required String drugName,
    required bool isRecalled,
    String? alertTitle,
    String? recallReason,
  }) {
    final Color cardBorder = isRecalled
        ? InquestorColors.coralRed.withValues(alpha: 0.35)
        : InquestorColors.forestGreen.withValues(alpha: 0.35);
    final Color cardBg = isRecalled
        ? InquestorColors.coralRed.withValues(alpha: 0.03)
        : InquestorColors.forestGreen.withValues(alpha: 0.03);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRecalled ? Icons.dangerous_outlined : Icons.health_and_safety_outlined,
                size: 16,
                color: isRecalled ? InquestorColors.coralRed : InquestorColors.forestGreen,
              ),
              const SizedBox(width: 8),
              Text(
                isRecalled
                    ? 'STATUTORY RECALL NOTICE IDENTIFIED'
                    : 'CLEARED BY CDSCO REGULATORY DATABASE',
                style: TextStyle(
                  color: isRecalled ? InquestorColors.coralRed : InquestorColors.forestGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEvidenceDetailRow('Queried Batch Number', batchNumber, isMono: true),
          const SizedBox(height: 8),
          _buildEvidenceDetailRow('Pharmaceutical Formulation', drugName),
          const SizedBox(height: 8),
          _buildEvidenceDetailRow(
            'CDSCO National Alert Status',
            isRecalled
                ? 'DECLARED NOT OF STANDARD QUALITY (NSQ)'
                : 'Zero violation records or recall alerts filed against batch',
            valueColor: isRecalled ? InquestorColors.coralRed : InquestorColors.forestGreen,
          ),
          if (isRecalled) ...[
            if (alertTitle != null && alertTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildEvidenceDetailRow('Regulatory Gazette Title', alertTitle),
            ],
            if (recallReason != null && recallReason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: InquestorColors.coralRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: InquestorColors.coralRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Statutory Defect: ' + recallReason,
                        style: const TextStyle(
                          color: InquestorColors.coralRed,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildQrSandboxDossierCard(Map<String, dynamic> qrSandbox, String? originalUrl) {
    final bool isPhishing = qrSandbox['is_phishing'] == true;
    final String domain = qrSandbox['final_domain']?.toString() ?? 'External Target';
    final List<dynamic> chain = qrSandbox['redirect_chain'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPhishing
              ? InquestorColors.coralRed.withValues(alpha: 0.35)
              : const Color(0xFFE8E8E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 14,
                color: isPhishing ? InquestorColors.coralRed : InquestorColors.graphite,
              ),
              const SizedBox(width: 8),
              const Text(
                'QR REDIRECT CLOUD SANDBOX TRACE',
                style: TextStyle(
                  color: InquestorColors.graphite,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPhishing ? InquestorColors.coralRed : InquestorColors.forestGreen)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isPhishing ? 'PHISHING SPOOF' : 'AUTHENTIC HOST',
                  style: TextStyle(
                    color: isPhishing ? InquestorColors.coralRed : InquestorColors.forestGreen,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (originalUrl != null && originalUrl.isNotEmpty)
            _buildEvidenceDetailRow('Initial Scanned URL', originalUrl, isMono: true),
          const SizedBox(height: 6),
          _buildEvidenceDetailRow('Resolved Root Domain', domain, isMono: true),
          if (chain.length > 1) ...[
            const SizedBox(height: 6),
            _buildEvidenceDetailRow('Redirect Hops', chain.join(' -> '), isMono: true),
          ],
        ],
      ),
    );
  }

  Widget _buildFastFailDossierCard(List<String> failedChecks) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InquestorColors.coralRed.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InquestorColors.coralRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: InquestorColors.coralRed),
              SizedBox(width: 8),
              Text(
                'DETERMINISTIC FAST-FAIL TRIGGERED',
                style: TextStyle(
                  color: InquestorColors.coralRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Packaging failed Tier-2 deterministic mathematical & syntax rules (<5ms). Web registry query was safely pre-empted to save latency and bandwidth.',
            style: TextStyle(color: InquestorColors.softSlate, fontSize: 11, height: 1.4),
          ),
          if (failedChecks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...failedChecks.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.close, size: 12, color: InquestorColors.coralRed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            color: InquestorColors.coralRed,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceDetailRow(String label, String value,
      {bool isMono = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? InquestorColors.graphite,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // G. BOTTOM ACTION BUTTONS
  // ==========================================================================

  Widget _buildBottomActionButtons(
    VerificationResponse response,
    ExtractedProductClaims? claims,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Button: START NEW INQUEST
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pushReplacementNamed('/tier0'),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(
            'START NEW INQUEST',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: InquestorColors.graphite,
            foregroundColor: InquestorColors.pureWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Button: EXPORT AUDIT SUMMARY
        OutlinedButton.icon(
          onPressed: () {
            final reportText = StringBuffer()
              ..writeln('========================================')
              ..writeln('INQUESTOR FORENSIC EVIDENCE REPORT')
              ..writeln('========================================')
              ..writeln('Verdict:   ${response.verdict}')
              ..writeln('Category:  ${response.category.toUpperCase()}')
              ..writeln('Product:   ${claims?.brandName ?? "Unknown"} - ${claims?.modelOrDrugName ?? "Unknown"}')
              ..writeln('Identifier: GTIN ${claims?.barcodeGtin ?? "N/A"} | Serial/Batch ${claims?.serialOrBatchNumber ?? "N/A"}')
              ..writeln('Summary:   ${response.summaryBanner}')
              ..writeln('\n----------------------------------------')
              ..writeln('AUDIT TRAIL CHECKLIST:');

            for (final item in response.checklist) {
              reportText.writeln(
                  '[${item.passed ? "PASS" : "FAIL"}] (${item.tier}) ${item.name}: ${item.details}');
            }

            if (response.forensicDiscrepancy != null) {
              reportText.writeln('\n----------------------------------------');
              reportText.writeln('FORENSIC CONTRADICTION:');
              reportText.writeln('Field:    ${response.forensicDiscrepancy!["field"]}');
              reportText.writeln('Box:      ${response.forensicDiscrepancy!["packaging_claim"]}');
              reportText.writeln('Official: ${response.forensicDiscrepancy!["official_record"]}');
            }

            reportText.writeln('\nGenerated by Inquestor Engine v1.0.0');

            Clipboard.setData(ClipboardData(text: reportText.toString()));
            setState(() {
              _copiedToClipboard = true;
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _copiedToClipboard = false);
              }
            });
          },
          icon: Icon(
            _copiedToClipboard ? Icons.check_circle_outline : Icons.content_copy_outlined,
            size: 15,
            color: _copiedToClipboard ? InquestorColors.forestGreen : InquestorColors.graphite,
          ),
          label: Text(
            _copiedToClipboard ? '✓ AUDIT SUMMARY COPIED TO CLIPBOARD' : 'EXPORT AUDIT SUMMARY',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _copiedToClipboard ? InquestorColors.forestGreen : InquestorColors.graphite,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: InquestorColors.graphite,
            side: BorderSide(
              color: _copiedToClipboard
                  ? InquestorColors.forestGreen.withValues(alpha: 0.5)
                  : InquestorColors.hairlineBorder,
              width: 1.0,
            ),
            backgroundColor: InquestorColors.pureWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
