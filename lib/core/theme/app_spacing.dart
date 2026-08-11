import 'package:flutter/material.dart';

/// ArtVault Design System — Spacing & Layout Tokens
///
/// Based on a 4-point base grid with semantic naming. All spacing,
/// radii, and layout constraints derive from these tokens.
abstract final class AppSpacing {
  // ===========================================================================
  // BASE SPACING SCALE (4-point grid)
  // ===========================================================================
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space9 = 36;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space14 = 56;
  static const double space16 = 64;
  static const double space18 = 72;
  static const double space20 = 80;
  static const double space24 = 96;

  // Semantic aliases for common use cases
  static const double none = space0;
  static const double xxs = space1;    // 4
  static const double xs = space2;     // 8
  static const double sm = space3;     // 12
  static const double md = space4;     // 16
  static const double lg = space6;     // 24
  static const double xl = space8;     // 32
  static const double xxl = space12;   // 48
  static const double xxxl = space16;  // 64

  // ===========================================================================
  // BORDER RADIUS SCALE
  // ===========================================================================
  static const double radiusNone = 0;
  static const double radiusXxs = 4;
  static const double radiusXs = 6;
  static const double radiusXsPlus = 8;
  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;
  static const double radiusXxxl = 28;
  static const double radiusFull = 9999;

  // Semantic aliases
  static const double radiusCard = 16;
  static const double radiusButton = 12;
  static const double radiusInput = 10;
  static const double radiusChip = 20;
  static const double radiusFab = 28;
  static const double radiusDialog = 24;
  static const double radiusBottomSheet = 24;
  static const double radiusAvatar = 9999;

  // ===========================================================================
  // COMMON EDGE INSETS
  // ===========================================================================
  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static const EdgeInsets screenPaddingLg = EdgeInsets.all(24);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(12);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(24);

  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  static const EdgeInsets buttonPaddingSm = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const EdgeInsets buttonPaddingLg = EdgeInsets.symmetric(horizontal: 28, vertical: 18);

  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  static const EdgeInsets chipPaddingLg = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets listTilePaddingSm = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

  static EdgeInsets horizontal(double value) => EdgeInsets.symmetric(horizontal: value);
  static EdgeInsets vertical(double value) => EdgeInsets.symmetric(vertical: value);
  static EdgeInsets all(double value) => EdgeInsets.all(value);
  static EdgeInsets symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  static EdgeInsets only({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) =>
      EdgeInsets.fromLTRB(left, top, right, bottom);

  // ===========================================================================
  // LAYOUT CONSTRAINTS
  // ===========================================================================
  static const double sectionGap = 32;
  static const double sectionGapSm = 20;
  static const double sectionGapLg = 48;

  static const double maxContentWidth = 720;
  static const double maxContentWidthLg = 1024;
  static const double maxContentWidthXl = 1280;

  static const double minTouchTarget = 48;
  static const double minTouchTargetSm = 40;

  // ===========================================================================
  // ICON SIZES
  // ===========================================================================
  static const double iconXxs = 12;
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 28;
  static const double iconXl = 32;
  static const double iconXxl = 40;
  static const double iconXxxl = 48;

  // ===========================================================================
  // AVATAR SIZES
  // ===========================================================================
  static const double avatarXxs = 20;
  static const double avatarXs = 28;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
  static const double avatarXl = 56;
  static const double avatarXxl = 72;
  static const double avatarXxxl = 96;
  static const double avatarXxxxl = 120;

  // ===========================================================================
  // ELEVATION LEVELS (Material 3 elevation + custom)
  // ===========================================================================
  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 3;
  static const double elevation3 = 6;
  static const double elevation4 = 8;
  static const double elevation5 = 12;

  static const double elevationCard = 0;      // Flat cards with border
  static const double elevationCardHover = 1;
  static const double elevationCardPressed = 0;
  static const double elevationFab = 3;
  static const double elevationFabHover = 4;
  static const double elevationDialog = 4;
  static const double elevationBottomSheet = 3;
  static const double elevationDropdown = 3;
  static const double elevationNavBar = 0;
  static const double elevationAppBar = 0;
  static const double elevationSnackbar = 3;
  static const double elevationTooltip = 3;
}

extension SpacingExtensions on BuildContext {
  /// Returns spacing based on screen size
  double responsiveSpace(double base) {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 600) return base;
    if (width < 900) return base * 1.25;
    return base * 1.5;
  }

  /// Screen padding responsive to device
  EdgeInsets get responsiveScreenPadding {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 600) return AppSpacing.screenPadding;
    if (width < 900) return AppSpacing.screenPaddingLg;
    return EdgeInsets.symmetric(horizontal: 48, vertical: 24);
  }
}

/// Responsive helper based on the current screen size.
/// Breaks the app into phone / tablet / desktop-foldable tiers.
abstract final class AppBreakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < phone;

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context).shortestSide;
    return size >= phone && size < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= desktop;

  /// Columns count used by adaptive masonry/grid galleries.
  static int galleryColumns(BuildContext context, {double minTile = 160}) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / minTile).floor().clamp(2, 8);
  }
}