import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'app_spacing.dart';

/// ArtVault Design System — Theme
///
/// A sophisticated, gallery-inspired design system with deep charcoal surfaces,
/// warm gold accents, teal AI highlights, and refined glassmorphism effects.
/// Supports light and dark modes with full Material 3 compliance.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Surface colors
    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final surfaceContainer = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;
    final surfaceContainerHigh = isDark
        ? AppColors.darkSurfaceContainerHigh
        : AppColors.lightSurfaceContainerHigh;
    final surfaceContainerHighest = isDark
        ? AppColors.darkSurfaceContainerHighest
        : AppColors.lightSurfaceContainerHighest;

    // Text colors
    final onSurface = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final onSurfaceVariant = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    // Outline
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final outlineVariant = isDark
        ? AppColors.darkOutlineVariant
        : AppColors.lightOutlineVariant;

    // Brand / accent colors
    final primary = isDark ? AppColors.brand100 : AppColors.brand700;
    final onPrimary = isDark ? AppColors.brand900 : Colors.white;
    final primaryContainer = isDark ? AppColors.brand700 : AppColors.brand100;
    final onPrimaryContainer = isDark ? AppColors.brand100 : AppColors.brand700;

    final secondary = isDark ? AppColors.gold400 : AppColors.gold500;
    final onSecondary = isDark ? AppColors.gold900 : Colors.white;
    final secondaryContainer = isDark ? AppColors.gold800 : AppColors.gold100;
    final onSecondaryContainer = isDark ? AppColors.gold100 : AppColors.gold700;

    final tertiary = isDark ? AppColors.teal300 : AppColors.teal500;
    final onTertiary = isDark ? AppColors.teal900 : Colors.white;
    final tertiaryContainer = isDark ? AppColors.teal800 : AppColors.teal100;
    final onTertiaryContainer = isDark ? AppColors.teal100 : AppColors.teal700;

    // Semantic colors
    final error = isDark ? AppColors.errorDark : AppColors.errorLight;
    final onError = isDark ? Colors.black : Colors.white;
    final errorContainer = isDark
        ? AppColors.errorDark.withValues(alpha: 0.15)
        : AppColors.errorLight.withValues(alpha: 0.15);
    final onErrorContainer = isDark
        ? AppColors.errorDark
        : AppColors.errorLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: background,
      surfaceContainerLow: surfaceVariant,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      inverseSurface: onSurface,
      inversePrimary: primaryContainer,
      shadow: Colors.black.withValues(alpha: 0.1),
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Transparent so the AmbientBackground gradient (injected via
      // MaterialApp.builder) shows through every Scaffold, letting
      // translucent surfaces read as glassmorphism.
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    return baseTheme.copyWith(
      // =======================================================================
      // TEXT THEME
      // =======================================================================
      textTheme: _buildTextTheme(baseTheme, isDark),

      // =======================================================================
      // APP BAR
      // =======================================================================
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.2,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: onSurface, size: 24),
      ),

      // =======================================================================
      // CARD
      // =======================================================================
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(color: outlineVariant, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // =======================================================================
      // NAVIGATION BAR
      // =======================================================================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.66)
            : AppColors.glassLight(opacity: 0.80),
        elevation: 0,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.12),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primary : onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? primary : onSurfaceVariant,
          );
        }),
      ),

      // =======================================================================
      // NAVIGATION RAIL (tablet/desktop)
      // =======================================================================
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme: IconThemeData(color: onSurfaceVariant, size: 24),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariant,
        ),
      ),

      // =======================================================================
      // CHIP
      // =======================================================================
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withValues(alpha: 0.12),
        disabledColor: surfaceVariant.withValues(alpha: 0.5),
        side: BorderSide(color: outlineVariant, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        padding: AppSpacing.chipPadding,
        elevation: 0,
        pressElevation: 0,
      ),

      // =======================================================================
      // INPUT FIELDS
      // =======================================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        isDense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: outlineVariant, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: outlineVariant, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(
            color: outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        hintStyle: GoogleFonts.inter(
          color: onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: GoogleFonts.inter(
          color: onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 12,
        ),
        errorStyle: GoogleFonts.inter(color: error, fontSize: 12),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
      ),

      // =======================================================================
      // BUTTONS
      // =======================================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onPrimary,
              disabledBackgroundColor: surfaceVariant,
              disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.5),
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              ),
              padding: AppSpacing.buttonPadding,
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return onPrimary.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return onPrimary.withValues(alpha: 0.12);
                }
                return null;
              }),
            ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: primary,
              disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.5),
              elevation: 0,
              side: BorderSide(color: primary.withValues(alpha: 0.5), width: 1),
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              ),
              padding: AppSpacing.buttonPadding,
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return primary.withValues(alpha: 0.06);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primary.withValues(alpha: 0.10);
                }
                return null;
              }),
            ),
      ),

      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: primary,
              disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.5),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              padding: AppSpacing.buttonPaddingSm,
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return primary.withValues(alpha: 0.06);
                }
                return null;
              }),
            ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: surfaceVariant,
          foregroundColor: onSurface,
          elevation: 0,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              foregroundColor: onSurface,
              disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.4),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return onSurface.withValues(alpha: 0.06);
                }
                return null;
              }),
            ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFab),
        ),
        extendedTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),

      // =======================================================================
      // DIALOG
      // =======================================================================
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.94)
            : AppColors.glassLight(opacity: 0.97),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
      ),

      // =======================================================================
      // BOTTOM SHEET
      // =======================================================================
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.92)
            : AppColors.glassLight(opacity: 0.96),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusBottomSheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: outlineVariant,
        dragHandleSize: const Size(36, 4),
      ),

      // =======================================================================
      // SNACK BAR
      // =======================================================================
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.brand800,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        elevation: 3,
        insetPadding: const EdgeInsets.all(16),
      ),

      // =======================================================================
      // DIVIDER
      // =======================================================================
      dividerTheme: DividerThemeData(
        color: outlineVariant,
        thickness: 0.5,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // ===========================================================================
      // LIST TILE
      // ===========================================================================
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        contentPadding: AppSpacing.listTilePadding,
        iconColor: onSurfaceVariant,
        textColor: onSurface,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
      ),

      // ===========================================================================
      // SWITCH
      // ===========================================================================
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryContainer;
          return surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ===========================================================================
      // CHECKBOX
      // ===========================================================================
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: BorderSide(color: outline, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxs),
        ),
      ),

      // ===========================================================================
      // RADIO
      // ===========================================================================
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return outline;
        }),
      ),

      // ===========================================================================
      // SEGMENTED BUTTON
      // ===========================================================================
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: onSurface,
          selectedForegroundColor: primary,
          selectedBackgroundColor: primary.withValues(alpha: 0.1),
          side: BorderSide(color: outlineVariant, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),

      // ===========================================================================
      // EXPANSION PANEL
      // ===========================================================================
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: onSurface,
        collapsedIconColor: onSurfaceVariant,
        textColor: onSurface,
        collapsedTextColor: onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),

      // ===========================================================================
      // TOOLTIP
      // ===========================================================================
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.brand800,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXsPlus),
          boxShadow: AppColors.shadowSm,
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ===========================================================================
      // PROGRESS INDICATORS
      // ===========================================================================
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: primary.withValues(alpha: 0.15),
        linearTrackColor: primary.withValues(alpha: 0.15),
        linearMinHeight: 4,
      ),

      // ===========================================================================
      // TABS
      // ===========================================================================
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabAlignment: TabAlignment.start,
      ),

      // ===========================================================================
      // SEARCH BAR
      // ===========================================================================
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(surfaceVariant),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // ===========================================================================
      // SEARCH VIEW
      // ===========================================================================
      searchViewTheme: SearchViewThemeData(
        backgroundColor: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ===========================================================================
      // PAGE TRANSITIONS
      // ===========================================================================
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(ThemeData base, bool isDark) {
    final onSurface = isDark
        ? AppColors.darkOnSurface
        : AppColors.lightOnSurface;
    final onSurfaceVariant = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    final baseTextTheme = base.textTheme;
    final inter = GoogleFonts.inter;
    final playfair = GoogleFonts.playfairDisplay;

    return baseTextTheme.copyWith(
      displayLarge: playfair(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.1,
      ),
      displayMedium: playfair(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.15,
      ),
      displaySmall: playfair(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.2,
      ),
      headlineLarge: playfair(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.2,
      ),
      headlineMedium: playfair(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.2,
      ),
      headlineSmall: inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.25,
      ),
      titleLarge: inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        height: 1.3,
      ),
      titleMedium: inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.35,
      ),
      titleSmall: inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      bodyLarge: inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.5,
      ),
      bodyMedium: inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
        height: 1.5,
      ),
      bodySmall: inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
        height: 1.45,
      ),
      labelLarge: inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.4,
      ),
      labelMedium: inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSurfaceVariant,
        height: 1.4,
      ),
      labelSmall: inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: onSurfaceVariant,
        height: 1.35,
      ),
    );
  }

  // ===========================================================================
  // DISPLAY HEADING (for hero titles across screens)
  // ===========================================================================
  static TextStyle display(BuildContext context, {double? size}) {
    return GoogleFonts.playfairDisplay(
      fontSize: size ?? 28,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.1,
      letterSpacing: -0.5,
    );
  }

  // ===========================================================================
  // UTILITY HELPERS
  // ===========================================================================
  static BorderRadius cardRadius = BorderRadius.circular(AppSpacing.radiusCard);
  static BorderRadius buttonRadius = BorderRadius.circular(
    AppSpacing.radiusButton,
  );
  static BorderRadius inputRadius = BorderRadius.circular(
    AppSpacing.radiusInput,
  );
  static BorderRadius chipRadius = BorderRadius.circular(AppSpacing.radiusChip);
  static BorderRadius dialogRadius = BorderRadius.circular(
    AppSpacing.radiusDialog,
  );
  static BorderRadius bottomSheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppSpacing.radiusBottomSheet),
  );
  static BorderRadius fullRadius = BorderRadius.circular(AppSpacing.radiusFull);
}
