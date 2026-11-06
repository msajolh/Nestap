import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Material 3 themes in Nestap colors, with Lato like nestap.net.
///
/// Light: white cards on a soft gray canvas, navy text, cyan accents.
/// Dark: navy cards on near-black, bright cyan accents.
/// Main buttons copy the site: bright cyan pill with navy text.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: dark ? AppColors.cyan400 : AppColors.cyan700,
      onPrimary: dark ? AppColors.navy : Colors.white,
      primaryContainer: dark ? AppColors.cyan700 : AppColors.cyan200,
      onPrimaryContainer: dark ? AppColors.cyan200 : AppColors.navy,
      secondary: dark ? AppColors.teal200 : AppColors.cyan500,
      onSecondary: AppColors.navy,
      tertiary: AppColors.brand,
      error: AppColors.error,
      surface: dark ? AppColors.navy : Colors.white,
      onSurface: dark ? AppColors.gray100 : AppColors.navy,
      onSurfaceVariant: dark ? AppColors.gray300 : AppColors.slate,
      surfaceContainerLowest: dark ? AppColors.ink : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF0A1120) : AppColors.gray50,
      surfaceContainer: dark ? AppColors.navy800 : AppColors.gray100,
      surfaceContainerHigh: dark ? AppColors.navy700 : AppColors.gray200,
      outline: dark ? AppColors.navy700 : AppColors.gray300,
      outlineVariant: dark ? AppColors.navy800 : AppColors.gray200,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = GoogleFonts.latoTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    const pill = StadiumBorder();
    const buttonSize = Size(64, 52);
    final buttonText = text.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(AppRadius.md),
      borderSide: BorderSide(color: scheme.outline),
    );

    return base.copyWith(
      scaffoldBackgroundColor: dark ? AppColors.ink : AppColors.gray50,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyan400,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          minimumSize: buttonSize,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: buttonSize,
          shape: pill,
          side: BorderSide(color: scheme.outline),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.navy800 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? AppColors.navy : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide(color: scheme.outline),
        selectedColor: AppColors.cyan400,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: AppColors.navy),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.navy : Colors.white,
        indicatorColor: AppColors.cyan400.withValues(alpha: dark ? 0.25 : 0.35),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? AppColors.navy : Colors.white,
        indicatorColor: AppColors.cyan400.withValues(alpha: dark ? 0.25 : 0.35),
        selectedLabelTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: text.labelLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.navy
              : (dark ? AppColors.gray300 : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan400
              : scheme.surfaceContainerHigh,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.cyan400,
        thumbColor: AppColors.cyan400,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(AppRadius.md)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
