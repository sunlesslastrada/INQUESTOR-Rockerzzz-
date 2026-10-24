import 'package:flutter/material.dart';

/// Design tokens and typography adhering strictly to the "Quiet Authority" design language.
class InquestorColors {
  InquestorColors._();

  /// Primary scaffold canvas background.
  static const Color porcelain = Color(0xFFF7F7F5);

  /// Elevated surfaces, cards, and interactive elements.
  static const Color pureWhite = Color(0xFFFFFFFF);

  /// Primary typography, glyph outlines, and solid CTA buttons.
  static const Color graphite = Color(0xFF292C2F);

  /// Secondary typography, metadata, and structural divider lines.
  static const Color softSlate = Color(0xFF73777A);

  /// Slightly lighter graphite for subheads and secondary headers.
  static const Color graphiteSubtle = Color(0xFF4A4E52);

  /// 1px crisp borders on cards and containers.
  static const Color hairlineBorder = Color(0xFFE5E5E2);

  /// Signature brand accent: flat, muted, non-metallic, strictly for focal dots/markers.
  static const Color antiqueGold = Color(0xFFAD925B);

  /// Subtle interactive hover overlay.
  static const Color hoverHighlight = Color(0xFFF0F0EE);
}

/// Theme definitions for INQUESTOR.
class InquestorTheme {
  InquestorTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: InquestorColors.porcelain,
      colorScheme: const ColorScheme.light(
        surface: InquestorColors.porcelain,
        primary: InquestorColors.graphite,
        secondary: InquestorColors.antiqueGold,
        onSurface: InquestorColors.graphite,
        onPrimary: InquestorColors.pureWhite,
      ),
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        '-apple-system',
        'BlinkMacSystemFont',
        'Segoe UI',
        'Roboto',
        'Helvetica Neue',
        'sans-serif',
      ],
      dividerColor: InquestorColors.hairlineBorder,
      dividerTheme: const DividerThemeData(
        color: InquestorColors.hairlineBorder,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}
