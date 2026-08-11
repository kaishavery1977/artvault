import 'package:flutter/material.dart';

/// ArtVault Design System — Color Palette
///
/// Inspired by modern gallery aesthetics: deep charcoal, warm gold accents,
/// soft neutrals, and refined semantics. Works beautifully in both light
/// and dark modes with full Material 3 dynamic color support.
abstract final class AppColors {
  // ===========================================================================
  // BRAND PALETTE
  // ===========================================================================

  // Primary brand - Deep charcoal with blue undertone
  static const Color brand50 = Color(0xFFF0F2F5);
  static const Color brand100 = Color(0xFFE0E4EB);
  static const Color brand200 = Color(0xFFC1C9D6);
  static const Color brand300 = Color(0xFF9AA3B8);
  static const Color brand400 = Color(0xFF72829B);
  static const Color brand500 = Color(0xFF53647E);
  static const Color brand600 = Color(0xFF3D4B68);
  static const Color brand700 = Color(0xFF2D3A55);
  static const Color brand800 = Color(0xFF1E2A42);
  static const Color brand900 = Color(0xFF141C30);
  static const Color brand950 = Color(0xFF0D1120);

  // Gold accent - Warm, sophisticated
  static const Color gold50 = Color(0xFFFFF8E7);
  static const Color gold100 = Color(0xFFFFF0C7);
  static const Color gold200 = Color(0xFFFFE18A);
  static const Color gold300 = Color(0xFFFFCE4A);
  static const Color gold400 = Color(0xFFFFBA14);
  static const Color gold500 = Color(0xFFF59E0B); // Primary gold
  static const Color gold600 = Color(0xFFD97706);
  static const Color gold700 = Color(0xFFB45309);
  static const Color gold800 = Color(0xFF92400E);
  static const Color gold900 = Color(0xFF78350F);
  static const Color gold950 = Color(0xFF451A03);

  // Teal accent - For AI/analytics highlights
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal300 = Color(0xFF5EEAD4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal800 = Color(0xFF115E59);
  static const Color teal900 = Color(0xFF134E4A);

  // ===========================================================================
  // LIGHT THEME SURFACES
  // ===========================================================================
  static const Color lightBackground = Color(0xFFFAFAFA);      // Near white
  static const Color lightSurface = Color(0xFFFFFFFF);         // Pure white
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);  // Subtle gray
  static const Color lightSurfaceContainer = Color(0xFFF0F0F0);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8E8E8);
  static const Color lightSurfaceContainerHighest = Color(0xFFE0E0E0);

  static const Color lightOnBackground = Color(0xFF1A1A2E);
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightOnSurfaceVariant = Color(0xFF52526B);
  static const Color lightOutline = Color(0xFFD6D6E0);
  static const Color lightOutlineVariant = Color(0xFFE8E8F0);

  // ===========================================================================
  // DARK THEME SURFACES
  // ===========================================================================
  static const Color darkBackground = Color(0xFF0A0A12);       // Deep navy-black
  static const Color darkSurface = Color(0xFF12121E);          // Elevated surface
  static const Color darkSurfaceVariant = Color(0xFF1A1A2E);   // Subtle elevation
  static const Color darkSurfaceContainer = Color(0xFF1E1E32);
  static const Color darkSurfaceContainerHigh = Color(0xFF2A2A3E);
  static const Color darkSurfaceContainerHighest = Color(0xFF36364A);

  static const Color darkOnBackground = Color(0xFFF5F5F5);
  static const Color darkOnSurface = Color(0xFFF5F5F5);
  static const Color darkOnSurfaceVariant = Color(0xFFC4C4D6);
  static const Color darkOutline = Color(0xFF3A3A52);
  static const Color darkOutlineVariant = Color(0xFF2E2E42);

  // ===========================================================================
  // BRAND COLORS (used for primary actions)
  // ===========================================================================
  static const Color primaryLight = Color(0xFF2D3A55);   // brand700
  static const Color primaryDark = Color(0xFFE0E4EB);    // brand100

  static const Color goldLight = Color(0xFFF59E0B);      // gold500
  static const Color goldDark = Color(0xFFFFBA14);       // gold400

  static const Color tealLight = Color(0xFF14B8A6);      // teal500
  static const Color tealDark = Color(0xFF5EEAD4);       // teal300

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
  // BACKWARD COMPATIBILITY ALIASES (for existing code)
  // ===========================================================================
  static const Color secondary = brand700;
  static const Color accent = gold500;
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
  /// Returns a glassmorphism surface color for the given theme.
  static Color glassLight({double opacity = 0.85}) => Colors.white.withValues(alpha: opacity);
  static Color glassDark({double opacity = 0.85}) => const Color(0xFF1A1A2E).withValues(alpha: opacity);

  static Color glassBorderLight({double opacity = 0.12}) => Colors.black.withValues(alpha: opacity);
  static Color glassBorderDark({double opacity = 0.12}) => Colors.white.withValues(alpha: opacity);

  // ===========================================================================
  // SHADOW TOKENS
  // ===========================================================================
  static const List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowInner = [
    BoxShadow(
      color: Color(0x1AFFFFFF),
      blurRadius: 2,
      offset: Offset(0, -1),
    ),
  ];
}

extension ColorSchemeExtensions on ColorScheme {
  /// Returns a glassmorphism surface color appropriate for the current brightness.
  Color get glassSurface => brightness == Brightness.light
      ? AppColors.glassLight()
      : AppColors.glassDark();

  Color get glassBorder => brightness == Brightness.light
      ? AppColors.glassBorderLight()
      : AppColors.glassBorderDark();
}