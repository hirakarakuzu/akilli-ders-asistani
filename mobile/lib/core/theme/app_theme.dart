import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.ice,
    onPrimaryContainer: AppColors.navy,
    secondary: AppColors.electric,
    onSecondary: AppColors.white,
    secondaryContainer: Color(0xFFD6E8FF),
    onSecondaryContainer: AppColors.navy,
    tertiary: AppColors.sky,
    onTertiary: AppColors.navy,
    tertiaryContainer: AppColors.ice,
    onTertiaryContainer: AppColors.navy,
    error: Color(0xFFBA1A1A),
    onError: AppColors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: AppColors.white,
    onSurface: AppColors.navy,
    onSurfaceVariant: Color(0xFF4A5875),
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: Color(0xFFF5F9FF),
    surfaceContainer: AppColors.ice,
    surfaceContainerHigh: Color(0xFFDDEBFB),
    surfaceContainerHighest: Color(0xFFD3E3F7),
    outline: Color(0xFF8A97B0),
    outlineVariant: Color(0xFFD0DCEE),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.navy,
    onInverseSurface: AppColors.ice,
    inversePrimary: AppColors.sky,
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.sky,
    onPrimary: AppColors.navy,
    primaryContainer: AppColors.primary,
    onPrimaryContainer: AppColors.ice,
    secondary: AppColors.electric,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.navyHigh,
    onSecondaryContainer: AppColors.ice,
    tertiary: AppColors.sky,
    onTertiary: AppColors.navy,
    tertiaryContainer: AppColors.navyMid,
    onTertiaryContainer: AppColors.ice,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.navy,
    onSurface: AppColors.ice,
    onSurfaceVariant: Color(0xFFA9B8D4),
    surfaceContainerLowest: Color(0xFF0B152D),
    surfaceContainerLow: AppColors.navyLow,
    surfaceContainer: AppColors.navyMid,
    surfaceContainerHigh: AppColors.navyHigh,
    surfaceContainerHighest: Color(0xFF2B4478),
    outline: Color(0xFF6F82A6),
    outlineVariant: Color(0xFF2E4373),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.ice,
    onInverseSurface: AppColors.navy,
    inversePrimary: AppColors.primary,
  );

  static ThemeData get light => _build(lightScheme);
  static ThemeData get dark => _build(darkScheme);

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs);
    final text = base.textTheme.apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: cs.primaryContainer,
        labelStyle: TextStyle(color: cs.onPrimaryContainer),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
