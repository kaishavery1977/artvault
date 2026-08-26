import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_spacing.dart';

// Local font helpers — bundled offline, no network flash.
TextStyle _inter({double? fontSize, FontWeight? fontWeight, Color? color, double? height, double? letterSpacing}) =>
    TextStyle(fontFamily: 'Inter', fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing);

TextStyle _playfair({double? fontSize, FontWeight? fontWeight, Color? color, double? height, double? letterSpacing}) =>
    TextStyle(fontFamily: 'PlayfairDisplay', fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing);

/// ArtVault Design System — Premium Theme
///
/// Deep navy-black surfaces with violet primary, cyan secondary, and rose
/// tertiary accents. Glassmorphism on all elevated surfaces (app bar,
/// nav bar, dialogs, sheets). Rich text colors on dark backgrounds.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Surface colors
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final surfaceContainer = isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurfaceContainer;
    final surfaceContainerHigh = isDark ? AppColors.darkSurfaceContainerHigh : AppColors.lightSurfaceContainerHigh;
    final surfaceContainerHighest = isDark ? AppColors.darkSurfaceContainerHighest : AppColors.lightSurfaceContainerHighest;

    // Text colors
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final onSurfaceVariant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    // Outline
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final outlineVariant = isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant;

    // === PRIMARY — Violet ===
    final primary = isDark ? AppColors.violet500 : AppColors.violet600;
    final onPrimary = isDark ? Colors.white : Colors.white;
    final primaryContainer = isDark ? AppColors.violet900 : AppColors.violet100;
    final onPrimaryContainer = isDark ? AppColors.violet200 : AppColors.violet800;

    // === SECONDARY — Cyan ===
    final secondary = isDark ? AppColors.cyan400 : AppColors.cyan600;
    final onSecondary = isDark ? AppColors.cyan900 : Colors.white;
    final secondaryContainer = isDark ? AppColors.cyan900 : AppColors.cyan100;
    final onSecondaryContainer = isDark ? AppColors.cyan200 : AppColors.cyan800;

    // === TERTIARY — Rose ===
    final tertiary = isDark ? AppColors.rose400 : AppColors.rose600;
    final onTertiary = isDark ? AppColors.rose900 : Colors.white;
    final tertiaryContainer = isDark ? AppColors.rose900 : AppColors.rose100;
    final onTertiaryContainer = isDark ? AppColors.rose200 : AppColors.rose700;

    // Semantic
    final error = isDark ? AppColors.errorDark : AppColors.errorLight;
    final onError = isDark ? Colors.black : Colors.white;
    final errorContainer = isDark
        ? AppColors.errorDark.withValues(alpha: 0.15)
        : AppColors.errorLight.withValues(alpha: 0.15);
    final onErrorContainer = isDark ? AppColors.errorDark : AppColors.errorLight;

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
      shadow: Colors.black.withValues(alpha: 0.3),
      surfaceTint: primary.withValues(alpha: isDark ? 0.06 : 0.04),
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Transparent for glassmorphism — the ambient gradient shows through.
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Inter',
    );

    return baseTheme.copyWith(
      // =======================================================================
      // TEXT THEME — Crisp white on dark, rich purple on light
      // =======================================================================
      textTheme: _buildTextTheme(baseTheme, isDark),

      // =======================================================================
      // APP BAR — Frosted glass with violet tint
      // =======================================================================
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.60)
            : AppColors.glassLight(opacity: 0.75),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.violet500.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.6,
          ),
        ),
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: _playfair(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          height: 1.2,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: onSurface, size: 24),
      ),

      // =======================================================================
      // CARD — Glass surface with subtle violet border in dark mode
      // =======================================================================
      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.glassDark(opacity: 0.70)
            : surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: BorderSide(
            color: isDark
                ? AppColors.violet500.withValues(alpha: 0.08)
                : outlineVariant,
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // =======================================================================
      // NAVIGATION BAR — Glassmorphism
      // =======================================================================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.60)
            : AppColors.glassLight(opacity: 0.80),
        elevation: 0,
        height: 64,
        indicatorColor: primary.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return _inter(
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
        backgroundColor: isDark ? AppColors.darkSurface : surface,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme: IconThemeData(color: onSurfaceVariant, size: 24),
        selectedLabelTextStyle: _inter(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
        unselectedLabelTextStyle: _inter(fontSize: 12, fontWeight: FontWeight.w500, color: onSurfaceVariant),
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
        labelStyle: _inter(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface),
        secondaryLabelStyle: _inter(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
        padding: AppSpacing.chipPadding,
        elevation: 0,
        pressElevation: 0,
      ),

      // =======================================================================
      // INPUT FIELDS — Glassmorphism fill with violet focus ring
      // =======================================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.violet500.withValues(alpha: 0.04)
            : surfaceVariant,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        hintStyle: _inter(color: onSurfaceVariant.withValues(alpha: 0.65), fontSize: 15, fontWeight: FontWeight.w400),
        labelStyle: _inter(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
        helperStyle: _inter(color: onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12),
        errorStyle: _inter(color: error, fontSize: 12),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
      ),

      // =======================================================================
      // BUTTONS — Violet primary, cyan outline, glassmorphism
      // =======================================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceVariant,
          disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return onPrimary.withValues(alpha: 0.08);
            if (states.contains(WidgetState.pressed)) return onPrimary.withValues(alpha: 0.12);
            return null;
          }),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.6),
          elevation: 0,
          side: BorderSide(color: primary.withValues(alpha: 0.4), width: 1),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return primary.withValues(alpha: 0.06);
            if (states.contains(WidgetState.pressed)) return primary.withValues(alpha: 0.10);
            return null;
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.6),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          padding: AppSpacing.buttonPaddingSm,
          textStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600),
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
          textStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.4),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
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
        extendedTextStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),

      // =======================================================================
      // DIALOG — Glassmorphism
      // =======================================================================
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.92)
            : AppColors.glassLight(opacity: 0.97),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
          side: BorderSide(
            color: isDark
                ? AppColors.violet500.withValues(alpha: 0.10)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        titleTextStyle: _playfair(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        contentTextStyle: _inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),

      // =======================================================================
      // BOTTOM SHEET — Glassmorphism
      // =======================================================================
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.glassDark(opacity: 0.90)
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
        backgroundColor: isDark ? AppColors.violet800 : AppColors.violet800,
        contentTextStyle: _inter(color: Colors.white, fontSize: 14),
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
        color: isDark
            ? AppColors.violet500.withValues(alpha: 0.08)
            : outlineVariant,
        thickness: 0.5,
        space: 1,
      ),

      // =======================================================================
      // LIST TILE
      // =======================================================================
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        contentPadding: AppSpacing.listTilePadding,
        iconColor: onSurfaceVariant,
        textColor: onSurface,
        titleTextStyle: _inter(fontSize: 15, fontWeight: FontWeight.w600),
        subtitleTextStyle: _inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
      ),

      // =======================================================================
      // SWITCH
      // =======================================================================
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

      // =======================================================================
      // CHECKBOX
      // =======================================================================
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

      // =======================================================================
      // RADIO
      // =======================================================================
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return outline;
        }),
      ),

      // =======================================================================
      // SEGMENTED BUTTON
      // =======================================================================
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: onSurface,
          selectedForegroundColor: primary,
          selectedBackgroundColor: primary.withValues(alpha: 0.1),
          side: BorderSide(color: outlineVariant, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: _inter(fontSize: 14, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),

      // =======================================================================
      // EXPANSION PANEL
      // =======================================================================
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

      // =======================================================================
      // TOOLTIP
      // =======================================================================
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.violet800 : AppColors.violet800,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXsPlus),
          boxShadow: AppColors.shadowSm,
        ),
        textStyle: _inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // =======================================================================
      // PROGRESS INDICATORS
      // =======================================================================
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: primary.withValues(alpha: 0.15),
        linearTrackColor: primary.withValues(alpha: 0.15),
        linearMinHeight: 4,
      ),

      // =======================================================================
      // TABS
      // =======================================================================
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: _inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _inter(fontSize: 14, fontWeight: FontWeight.w500),
        tabAlignment: TabAlignment.start,
      ),

      // =======================================================================
      // SEARCH BAR
      // =======================================================================
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(
          isDark ? AppColors.violet500.withValues(alpha: 0.04) : surfaceVariant,
        ),
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            side: BorderSide(color: outlineVariant, width: 0.5),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // =======================================================================
      // SEARCH VIEW
      // =======================================================================
      searchViewTheme: SearchViewThemeData(
        backgroundColor: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // =======================================================================
      // PAGE TRANSITIONS
      // =======================================================================
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(ThemeData base, bool isDark) {
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final onSurfaceVariant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    final baseTextTheme = base.textTheme;
    final inter = _inter;
    final playfair = _playfair;

    return baseTextTheme.copyWith(
      displayLarge: playfair(fontSize: 36, fontWeight: FontWeight.w700, color: onSurface, height: 1.1),
      displayMedium: playfair(fontSize: 30, fontWeight: FontWeight.w700, color: onSurface, height: 1.15),
      displaySmall: playfair(fontSize: 26, fontWeight: FontWeight.w600, color: onSurface, height: 1.2),
      headlineLarge: playfair(fontSize: 24, fontWeight: FontWeight.w600, color: onSurface, height: 1.2),
      headlineMedium: playfair(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface, height: 1.2),
      headlineSmall: inter(fontSize: 20, fontWeight: FontWeight.w700, color: onSurface, height: 1.25),
      titleLarge: inter(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface, height: 1.3),
      titleMedium: inter(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface, height: 1.35),
      titleSmall: inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, height: 1.4),
      bodyLarge: inter(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface, height: 1.5),
      bodyMedium: inter(fontSize: 14, fontWeight: FontWeight.w400, color: onSurfaceVariant, height: 1.5),
      bodySmall: inter(fontSize: 13, fontWeight: FontWeight.w400, color: onSurfaceVariant, height: 1.45),
      labelLarge: inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, height: 1.4),
      labelMedium: inter(fontSize: 13, fontWeight: FontWeight.w600, color: onSurfaceVariant, height: 1.4),
      labelSmall: inter(fontSize: 11, fontWeight: FontWeight.w600, color: onSurfaceVariant, height: 1.35),
    );
  }

  /// Display heading for hero titles across screens.
  static TextStyle display(BuildContext context, {double? size}) {
    return _playfair(
      fontSize: size ?? 28,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.1,
      letterSpacing: -0.5,
    );
  }

  // Utility helpers
  static BorderRadius cardRadius = BorderRadius.circular(AppSpacing.radiusCard);
  static BorderRadius buttonRadius = BorderRadius.circular(AppSpacing.radiusButton);
  static BorderRadius inputRadius = BorderRadius.circular(AppSpacing.radiusInput);
  static BorderRadius chipRadius = BorderRadius.circular(AppSpacing.radiusChip);
  static BorderRadius dialogRadius = BorderRadius.circular(AppSpacing.radiusDialog);
  static BorderRadius bottomSheetRadius = BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusBottomSheet));
  static BorderRadius fullRadius = BorderRadius.circular(AppSpacing.radiusFull);
}
