import 'package:flutter/material.dart';

// Export theme definitions so landing_page.dart is completely self-contained.
export 'theme/inquestor_theme.dart';
import 'theme/inquestor_theme.dart';
import 'widgets/inquestor_background.dart';

// ============================================================================
// 1. BRAND ASSETS & CUSTOM PAINTER
// ============================================================================

/// CustomPainter for the INQUESTOR geometric brand mark:
/// A crisp 20x20px square with a graphite border (stroke width 2px)
/// and a tiny centered antique gold circular dot.
class InquestorLogoPainter extends CustomPainter {
  const InquestorLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Graphite square outline
    final strokePaint = Paint()
      ..color = InquestorColors.graphite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Inset slightly so the 2px stroke is perfectly aligned within bounds
    final rect = Rect.fromLTWH(1.0, 1.0, size.width - 2.0, size.height - 2.0);
    canvas.drawRect(rect, strokePaint);

    // 2. Centered antique gold dot (flat, muted, non-metallic)
    final dotPaint = Paint()
      ..color = InquestorColors.antiqueGold
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    const dotRadius = 2.5;
    canvas.drawCircle(center, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Standalone 20x20 geometric logo widget used as a baseline fallback
class InquestorLogoMark extends StatelessWidget {
  const InquestorLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: InquestorLogoPainter(),
      ),
    );
  }
}

/// The official brand emblem for INQUESTOR.
/// Renders the uploaded brand logo image asset with a graceful geometric fallback via [errorBuilder].
class InquestorBrandMark extends StatelessWidget {
  final double height;
  final BoxFit fit;

  const InquestorBrandMark({
    super.key,
    this.height = 26,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        'assets/images/inquestor_logo.png',
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Graceful fallback to the geometric outline painter if asset is unavailable
          return const InquestorLogoMark();
        },
      ),
    );
  }
}

/// Brand header combining the official emblem and the tracked uppercase wordmark.
class InquestorBrandHeader extends StatelessWidget {
  final VoidCallback? onTap;

  const InquestorBrandHeader({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InquestorBrandMark(height: 26),
          SizedBox(width: 12),
          Text(
            'INQUESTOR',
            style: TextStyle(
              color: InquestorColors.graphite,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. MAIN RESPONSIVE LANDING PAGE
// ============================================================================

/// The responsive, web-first Landing Page for INQUESTOR.
/// Adheres strictly to the "Quiet Authority" visual design language:
/// - Apple-inspired restraint and generous whitespace.
/// - 1px crisp borders, zero flashiness/neons/heavy gradients.
/// - Porcelain canvas background (#F7F7F5) with Pure White (#FFFFFF) elevated surfaces.
class LandingPage extends StatefulWidget {
  /// Optional callback override for the primary CTA button.
  /// Defaults to `Navigator.pushNamed(context, '/tier0')`.
  final VoidCallback? onInitiateInquest;

  const LandingPage({super.key, this.onInitiateInquest});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleInitiateInquest() {
    if (widget.onInitiateInquest != null) {
      widget.onInitiateInquest!();
    } else {
      Navigator.of(context).pushNamed('/tier0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: InquestorBackground(
        child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 860;
          final double horizontalPadding = isMobile ? 20.0 : 40.0;

          return Column(
            children: [
              // -------------------------------------------------------------
              // Fixed Top Navigation Bar with 1px hairline bottom border
              // -------------------------------------------------------------
              _InquestorNavigationBar(
                isMobile: isMobile,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                onBrandTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),

              // -------------------------------------------------------------
              // Scrollable Main Content Container
              // -------------------------------------------------------------
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isMobile ? 48 : 84),

                            // A. Hero Section
                            _HeroSection(
                              isMobile: isMobile,
                              onInitiateInquest: _handleInitiateInquest,
                            ),

                            SizedBox(height: isMobile ? 64 : 100),

                            // Divider line between sections
                            const _HairlineDivider(),

                            SizedBox(height: isMobile ? 56 : 80),

                            // B. 3-Tier Forensic Pipeline Overview
                            _PipelineSection(isMobile: isMobile),

                            SizedBox(height: isMobile ? 56 : 80),

                            // Divider line between sections
                            const _HairlineDivider(),

                            SizedBox(height: isMobile ? 56 : 80),

                            // C. Supported Industry Tracks
                            _IndustryTracksSection(isMobile: isMobile),

                            SizedBox(height: isMobile ? 64 : 100),

                            // D. Minimal Footer
                            const _FooterSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

// ============================================================================
// 3. SECTION COMPONENTS
// ============================================================================

/// Top fixed navigation bar.
class _InquestorNavigationBar extends StatelessWidget {
  final bool isMobile;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onBrandTap;

  const _InquestorNavigationBar({
    required this.isMobile,
    required this.padding,
    this.onBrandTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
      ),
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Geometric brand mark & wordmark
              InquestorBrandHeader(onTap: onBrandTap),

              // Right: Subtle metadata pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: InquestorColors.pureWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: InquestorColors.antiqueGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'v.1.6.7',
                      style: TextStyle(
                        color: InquestorColors.softSlate,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Hero Section containing the category badge, main headline,
/// premise value proposition, and the primary CTA button.
class _HeroSection extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onInitiateInquest;

  const _HeroSection({
    required this.isMobile,
    required this.onInitiateInquest,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 0. Hero Brand Emblem
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: InquestorBrandMark(
                height: isMobile ? 60 : 72,
                fit: BoxFit.contain,
              ),
            ),

            // 1. Understated Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: InquestorColors.pureWhite,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: InquestorColors.hairlineBorder,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '◈',
                    style: TextStyle(
                      color: InquestorColors.antiqueGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Autonomous Forensic Product Verification',
                    style: TextStyle(
                      color: InquestorColors.graphite.withValues(alpha: 0.85),
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 24 : 32),

            // 2. Main Headline ("From Scan to Trust.")
            Text(
              'From Scan to Trust.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InquestorColors.graphite,
                fontSize: isMobile ? 36 : 56,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 1.08,
              ),
            ),

            const SizedBox(height: 12),

            // 3. Graphite Subhead ("Don't just scan a product. Verify its evidence.")
            Text(
              "Don't just scan a product. Verify its evidence.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InquestorColors.graphiteSubtle,
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
                height: 1.25,
              ),
            ),

            SizedBox(height: isMobile ? 20 : 28),

            // 4. Value Proposition
            Text(
              'Standard scanners stop at barcode syntax. Inquestor executes an evidentiary '
              'investigation across packaging print geometry, deterministic GS1 logic, and live '
              'authoritative registry agents to expose counterfeit electronics and medicines.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InquestorColors.softSlate,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                height: 1.6,
              ),
            ),

            SizedBox(height: isMobile ? 32 : 40),

            // 5. Primary Call-to-Action (Solid Graphite Button)
            _PrimaryCtaButton(
              label: 'Initiate Product Inquest →',
              onPressed: onInitiateInquest,
            ),

            const SizedBox(height: 14),

            // 6. Micro-caption
            const Text(
              'Zero setup required · Works on camera capture or image upload',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InquestorColors.softSlate,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 3-Tier Forensic Pipeline Overview Grid.
class _PipelineSection extends StatelessWidget {
  final bool isMobile;

  const _PipelineSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Text(
          'THE 3-TIER FORENSIC PIPELINE',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Multi-layered verification architecture',
          style: TextStyle(
            color: InquestorColors.graphite,
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Each layer acts as an autonomous forensic gatekeeper, escalating only anomalies that demand deep investigation.',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // Three Cards Layout: 3-column row on desktop, vertical stack on mobile
        if (isMobile)
          const Column(
            children: [
              _PipelineCard(
                tierBadge: 'TIER 0 & 1',
                title: 'Packaging Vision & Ingestion',
                subhead: 'Multimodal Visual Inspection',
                body:
                    'Inspects packaging print kerning, trademark logo geometry, and extracts serial/batch credentials via Vision.',
                iconData: Icons.camera_alt_outlined,
              ),
              SizedBox(height: 16),
              _PipelineCard(
                tierBadge: 'TIER 2',
                title: 'Deterministic Rule Gatekeeper',
                subhead: '<50ms Fast-Fail Logic',
                body:
                    'Validates GS1 Modulo-10 checksums, serial regex structures, temporal expiry dates, and QR redirect phishing domains.',
                iconData: Icons.bolt_outlined,
              ),
              SizedBox(height: 16),
              _PipelineCard(
                tierBadge: 'TIER 3',
                title: 'Authoritative Ground Truth',
                subhead: 'TinyFish Web Agent & Fetch',
                body:
                    'Interactively audits live OEM warranty portals (Dell, Sony, Apple) and CDSCO national drug recall noticeboards.',
                iconData: Icons.travel_explore_outlined,
              ),
            ],
          )
        else
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PipelineCard(
                  tierBadge: 'TIER 0 & 1',
                  title: 'Packaging Vision & Ingestion',
                  subhead: 'Multimodal Visual Inspection',
                  body:
                      'Inspects packaging print kerning, trademark logo geometry, and extracts serial/batch credentials via Vision.',
                  iconData: Icons.camera_alt_outlined,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: _PipelineCard(
                  tierBadge: 'TIER 2',
                  title: 'Deterministic Rule Gatekeeper',
                  subhead: '<50ms Fast-Fail Logic',
                  body:
                      'Validates GS1 Modulo-10 checksums, serial regex structures, temporal expiry dates, and QR redirect phishing domains.',
                  iconData: Icons.bolt_outlined,
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: _PipelineCard(
                  tierBadge: 'TIER 3',
                  title: 'Authoritative Ground Truth',
                  subhead: 'TinyFish Web Agent & Fetch',
                  body:
                      'Interactively audits live OEM warranty portals (Dell, Sony, Apple) and CDSCO national drug recall noticeboards.',
                  iconData: Icons.travel_explore_outlined,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A single card within the 3-Tier Pipeline section.
class _PipelineCard extends StatefulWidget {
  final String tierBadge;
  final String title;
  final String subhead;
  final String body;
  final IconData iconData;

  const _PipelineCard({
    required this.tierBadge,
    required this.title,
    required this.subhead,
    required this.body,
    required this.iconData,
  });

  @override
  State<_PipelineCard> createState() => _PipelineCardState();
}

class _PipelineCardState extends State<_PipelineCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: InquestorColors.pureWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? InquestorColors.graphite.withValues(alpha: 0.35)
                : InquestorColors.hairlineBorder,
            width: 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: InquestorColors.graphite.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Icon and Tier Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minimal icon container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: InquestorColors.porcelain,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    widget.iconData,
                    size: 18,
                    color: InquestorColors.graphite,
                  ),
                ),

                // Tier badge with gold dot indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: InquestorColors.porcelain,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: InquestorColors.hairlineBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: InquestorColors.antiqueGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.tierBadge,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Card Title
            Text(
              widget.title,
              style: const TextStyle(
                color: InquestorColors.graphite,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 6),

            // Subhead
            Text(
              widget.subhead,
              style: const TextStyle(
                color: InquestorColors.antiqueGold,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),

            const SizedBox(height: 14),

            // Body
            Text(
              widget.body,
              style: const TextStyle(
                color: InquestorColors.softSlate,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Supported Industry Tracks Section.
class _IndustryTracksSection extends StatelessWidget {
  final bool isMobile;

  const _IndustryTracksSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Text(
          'INDUSTRY SPECIALIZATIONS',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tailored verification pipelines',
          style: TextStyle(
            color: InquestorColors.graphite,
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Engineered for the critical supply chains most severely targeted by illicit counterfeit networks.',
          style: TextStyle(
            color: InquestorColors.softSlate,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // Comparison block: 2 columns on desktop, stacked on mobile
        if (isMobile)
          const Column(
            children: [
              _IndustryTrackCard(
                title: 'Consumer Electronics',
                description:
                    'Forensic hardware audits targeting counterfeit microchips, grey-market clones, and manipulated warranty identifiers.',
                iconData: Icons.memory_outlined,
                features: [
                  'Serial cloning detection & batch collision',
                  'Live OEM warranty validity cross-referencing',
                  'Model & component spec discrepancy analysis',
                ],
              ),
              SizedBox(height: 16),
              _IndustryTrackCard(
                title: 'Pharmaceuticals & Healthcare',
                description:
                    'Evidentiary verification defending patients against fraudulent medication packaging, expired batches, and fake barcodes.',
                iconData: Icons.medication_outlined,
                features: [
                  'Blister-pack foil consistency & typography kerning',
                  'CDSCO national batch recall table verification',
                  'GS1 India SmartSearch authoritative registry lookup',
                ],
              ),
            ],
          )
        else
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _IndustryTrackCard(
                  title: 'Consumer Electronics',
                  description:
                      'Forensic hardware audits targeting counterfeit microchips, grey-market clones, and manipulated warranty identifiers.',
                  iconData: Icons.memory_outlined,
                  features: [
                    'Serial cloning detection & batch collision',
                    'Live OEM warranty validity cross-referencing',
                    'Model & component spec discrepancy analysis',
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: _IndustryTrackCard(
                  title: 'Pharmaceuticals & Healthcare',
                  description:
                      'Evidentiary verification defending patients against fraudulent medication packaging, expired batches, and fake barcodes.',
                  iconData: Icons.medication_outlined,
                  features: [
                    'Blister-pack foil consistency & typography kerning',
                    'CDSCO national batch recall table verification',
                    'GS1 India SmartSearch authoritative registry lookup',
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A dedicated card for each industry track.
class _IndustryTrackCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData iconData;
  final List<String> features;

  const _IndustryTrackCard({
    required this.title,
    required this.description,
    required this.iconData,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: InquestorColors.porcelain,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: InquestorColors.hairlineBorder,
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  iconData,
                  size: 18,
                  color: InquestorColors.graphite,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: InquestorColors.graphite,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            description,
            style: const TextStyle(
              color: InquestorColors.softSlate,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Features breakdown with antique gold focal markers
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((feature) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: InquestorColors.antiqueGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: InquestorColors.graphite,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Minimal footer displaying system origin and architectural principles.
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 32),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: InquestorColors.hairlineBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Center(
        child: Text(
          'Inquestor Forensic Engine · Built with TinyFish APIs for HackIIITD · Explainable Decision Architecture',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: InquestorColors.softSlate.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MICRO UI ATOMS
// ============================================================================

/// Primary Call-to-Action solid Graphite button with Apple-style smooth interaction.
class _PrimaryCtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryCtaButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_PrimaryCtaButton> createState() => _PrimaryCtaButtonState();
}

class _PrimaryCtaButtonState extends State<_PrimaryCtaButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFF1B1D1F)
                : _isHovered
                    ? const Color(0xFF383C40)
                    : InquestorColors.graphite,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: InquestorColors.graphite,
              width: 1.0,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: InquestorColors.pureWhite,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Crisp 1px structural hairline divider line.
class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.0,
      width: double.infinity,
      color: InquestorColors.hairlineBorder,
    );
  }
}
