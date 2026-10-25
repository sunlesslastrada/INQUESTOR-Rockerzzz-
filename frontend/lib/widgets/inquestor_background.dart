import 'package:flutter/material.dart';

/// Architectural porcelain textured background for Inquestor screens.
///
/// Implements a tactile, visible technical stationery atmosphere adhering to
/// the "Quiet Authority" design language: an architectural porcelain paper gradient
/// paired with an intentionally visible micro-dot matrix, geometric hairline grid,
/// and precision crosshair registration ticks.
///
/// Ensures pure white cards (#FFFFFF) and 1px hairline borders (#E5E5E2) pop
/// with tangible depth, looking like authoritative dossiers placed on archival paper.
class InquestorBackground extends StatelessWidget {
  final Widget child;

  const InquestorBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.0, -1.0),
          end: Alignment(0.0, 1.0),
          colors: [
            Color(0xFFFAF9F6), // Luminous top off-white porcelain
            Color(0xFFF3EFE7), // Warm linen stationery tone
            Color(0xFFECE7DC), // Architectural drafting paper mid
            Color(0xFFE2DDD1), // Tangible depth ground tone
          ],
          stops: [0.0, 0.32, 0.68, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: const _ForensicStationeryGridPainter(),
        child: child,
      ),
    );
  }
}

/// Custom painter rendering a crisp, tangible forensic drafting grid.
/// Combines a 28px micro-dot matrix, a 140px architectural hairline grid,
/// and distinct precision crosshairs at major grid intersections.
class _ForensicStationeryGridPainter extends CustomPainter {
  const _ForensicStationeryGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Intentionally visible coordinate dots
    final dotPaint = Paint()
      ..color = const Color(0xFF292C2F).withValues(alpha: 0.11)
      ..style = PaintingStyle.fill;

    // Faint architectural guideline grid lines
    final hairlinePaint = Paint()
      ..color = const Color(0xFF292C2F).withValues(alpha: 0.065)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    // Technical crosshair registration marks at major intersections
    final crosshairPaint = Paint()
      ..color = const Color(0xFF292C2F).withValues(alpha: 0.16)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double dotSpacing = 28.0;
    const double majorGridSpacing = 140.0; // 5 x dotSpacing

    // 1. Draw 140px architectural guideline grid
    for (double x = majorGridSpacing; x < size.width; x += majorGridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), hairlinePaint);
    }
    for (double y = majorGridSpacing; y < size.height; y += majorGridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hairlinePaint);
    }

    // 2. Draw 28px micro-dot matrix and crosshair ticks
    for (double x = dotSpacing; x < size.width; x += dotSpacing) {
      for (double y = dotSpacing; y < size.height; y += dotSpacing) {
        // Check if point coincides with a major grid intersection
        final isMajorX = (x % majorGridSpacing).abs() < 1.0;
        final isMajorY = (y % majorGridSpacing).abs() < 1.0;

        if (isMajorX && isMajorY) {
          // Draw technical crosshair mark (+) at major intersections
          const double tick = 4.5;
          canvas.drawLine(Offset(x - tick, y), Offset(x + tick, y), crosshairPaint);
          canvas.drawLine(Offset(x, y - tick), Offset(x, y + tick), crosshairPaint);
        } else {
          // Draw crisp coordinate dot
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
