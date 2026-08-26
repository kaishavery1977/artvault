import 'package:flutter/material.dart';

/// ArtVault Design System — Premium Color Palette
///
/// A bold, gallery-worthy palette built on deep navy-black surfaces with
/// three rich accent colors: Violet (primary), Cyan (secondary/tech),
/// and Rose (tertiary/warmth). Every color is chosen to feel premium,
/// not generic.
abstract final class AppColors {
  // ===========================================================================
  // VIOLET — Primary brand accent (premium, distinctive)
  // ===========================================================================
  static const Color violet50 = Color(0xFFF5F3FF);
  static const Color violet100 = Color(0xFFEDE9FE);
  static const Color violet200 = Color(0xFFDDD6FE);
  static const Color violet300 = Color(0xFFC4B5FD);
  static const Color violet400 = Color(0xFFA78BFA);
  static const Color violet500 = Color(0xFF8B5CF6); // Primary violet
  static const Color violet600 = Color(0xFF7C3AED);
  static const Color violet700 = Color(0xFF6D28D9);
  static const Color violet800 = Color(0xFF5B21B6);
  static const Color violet900 = Color(0xFF4C1D95);

  // ===========================================================================
  // CYAN — Secondary accent (tech, AI, analytics)
  // ===========================================================================
  static const Color cyan50 = Color(0xFFECFEFF);
  static const Color cyan100 = Color(0xFFCFFAFE);
  static const Color cyan200 = Color(0xFFA5F3FC);
  static const Color cyan300 = Color(0xFF67E8F9);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4); // Primary cyan
  static const Color cyan600 = Color(0xFF0891B2);
  static const Color cyan700 = Color(0xFF0E7490);
  static const Color cyan800 = Color(0xFF155E75);
  static const Color cyan900 = Color(0xFF164E63);

  // ===========================================================================
  // ROSE — Tertiary accent (warmth, favorites, alerts)
  // ===========================================================================
  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose300 = Color(0xFFFDA4AF);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E); // Primary rose
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose800 = Color(0xFF9F1239);
  static const Color rose900 = Color(0xFF881337);

  // ===========================================================================
  // LIGHT THEME SURFACES
  // ===========================================================================
  static const Color lightBackground = Color(0xFFF8F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F1F6);
  static const Color lightSurfaceContainer = Color(0xFFECECF2);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E2EC);
  static const Color lightSurfaceContainerHighest = Color(0xFFD6D6E2);

  static const Color lightOnBackground = Color(0xFF1A1A2E);
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightOnSurfaceVariant = Color(0xFF6B6B82);
  static const Color lightOutline = Color(0xFFCDCDD8);
  static const Color lightOutlineVariant = Color(0xFFE0E0EA);

  // ===========================================================================
  // DARK THEME SURFACES — Deep navy with blue-purple undertone
  // ===========================================================================
  static const Color darkBackground = Color(0xFF08090F);      // Near-black with blue tint
  static const Color darkSurface = Color(0xFF0F1019);         // Elevated surface
  static const Color darkSurfaceVariant = Color(0xFF161825);  // Subtle elevation
  static const Color darkSurfaceContainer = Color(0xFF1C1F30);
  static const Color darkSurfaceContainerHigh = Color(0xFF252840);
  static const Color darkSurfaceContainerHighest = Color(0xFF30334E);

  // Tinted surface variants — subtle violet undertone for M3 tonal elevation
  static const Color darkSurfaceTintLow = Color(0xFF111222);
  static const Color darkSurfaceTintMid = Color(0xFF181A2E);
  static const Color darkSurfaceTintHigh = Color(0xFF202240);

  static const Color darkOnBackground = Color(0xFFF0F0F5);    // Crisp cool white
  static const Color darkOnSurface = Color(0xFFF0F0F5);
  static const Color darkOnSurfaceVariant = Color(0xFFA8A8C0); // Soft lavender
  static const Color darkOutline = Color(0xFF3A3C55);
  static const Color darkOutlineVariant = Color(0xFF2A2C42);

  // ===========================================================================
  // SEMANTIC COLORS
  // ===========================================================================
  static const Color successLight = Color(0xFF059669);
  static const Color successDark = Color(0xFF34D399);

  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFFBBF24);

  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);

  static const Color infoLight = Color(0xFF2563EB);
  static const Color infoDark = Color(0xFF60A5FA);

  // ===========================================================================
  // BACKWARD COMPATIBILITY ALIASES
  // ===========================================================================
  // NOTE: These alias AppColors.secondary / AppColors.accent are NOT the
  // same as ColorScheme.secondary. In new code, use Theme.of(context)
  // .colorScheme.primary / .secondary / .error instead.
  static const Color secondary = violet700;
  static const Color accent = violet500;
  static const Color error = errorLight;
  static const Color success = successLight;
  static const Color warning = warningLight;
  static const Color info = infoLight;
  static const Color darkCard = darkSurface;
  static const Color lightCard = lightSurface;
  static const Color darkText = darkOnSurface;
  static const Color lightText = lightOnSurface;
  static const Color darkTextMuted = darkOnSurfaceVariant;
  static const Color lightTextMuted = lightOnSurfaceVariant;

  // ===========================================================================
  // GLASSMORPHISM HELPERS
  // ===========================================================================
  static Color glassLight({double opacity = 0.85}) =>
      Colors.white.withValues(alpha: opacity);
  static Color glassDark({double opacity = 0.85}) =>
      const Color(0xFF14162A).withValues(alpha: opacity);

  static Color glassBorderLight({double opacity = 0.12}) =>
      Colors.black.withValues(alpha: opacity);
  static Color glassBorderDark({double opacity = 0.15}) =>
      Colors.white.withValues(alpha: opacity);

  /// Glassmorphism border with a colored tint (for premium cards).
  static Color glassBorderTinted({double opacity = 0.12}) =>
      violet400.withValues(alpha: opacity);

  // ===========================================================================
  // SHADOW TOKENS
  // ===========================================================================
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowXl = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowInner = [
    BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 2, offset: Offset(0, -1)),
  ];

  // Premium colored shadows
  static List<BoxShadow> glowViolet({double opacity = 0.3}) => [
    BoxShadow(
      color: violet500.withValues(alpha: opacity),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> glowCyan({double opacity = 0.25}) => [
    BoxShadow(
      color: cyan500.withValues(alpha: opacity),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];
}

extension ColorSchemeExtensions on ColorScheme {
  Color get glassSurface => brightness == Brightness.light
      ? AppColors.glassLight()
      : AppColors.glassDark();

  Color get glassBorder => brightness == Brightness.light
      ? AppColors.glassBorderLight()
      : AppColors.glassBorderDark();
}
