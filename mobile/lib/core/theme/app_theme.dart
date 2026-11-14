import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Yazı tipleri: gövde Plus Jakarta Sans, başlıklar Manrope (assets/fonts içinde).
class AppFonts {
  AppFonts._();
  static const body = 'Jakarta';
  static const heading = 'Manrope';
}

class AppTheme {
  AppTheme._();

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: Color(0xFFEEE8FF),
    onPrimaryContainer: Color(0xFF2E1F66),
    secondary: AppColors.electric,
    onSecondary: AppColors.white,
    secondaryContainer: Color(0xFFE3F1FB),
    onSecondaryContainer: Color(0xFF0F3A57),
    tertiary: Color(0xFFD9483A),
    onTertiary: AppColors.white,
    tertiaryContainer: Color(0xFFFFE6E2),
    onTertiaryContainer: Color(0xFF5A1A12),
    error: Color(0xFFC62828),
    onError: AppColors.white,
    errorContainer: Color(0xFFFDE7E7),
    onErrorContainer: Color(0xFF5F1414),
    surface: AppColors.bg,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.white,
    surfaceContainer: Color(0xFFF4F4F6),
    surfaceContainerHigh: Color(0xFFEDEDF1),
    surfaceContainerHighest: Color(0xFFE4E4EA),
    outline: AppColors.muted,
    outlineVariant: Color(0xFFECECF0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.ink,
    onInverseSurface: Color(0xFFF4F4F6),
    inversePrimary: Color(0xFFC9B8FF),
  );

  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB9A3F5),
    onPrimary: Color(0xFF24164F),
    primaryContainer: Color(0xFF3A2C70),
    onPrimaryContainer: Color(0xFFEDE6FF),
    secondary: Color(0xFF8CC8EE),
    onSecondary: Color(0xFF0C2E45),
    secondaryContainer: Color(0xFF1D3A52),
    onSecondaryContainer: Color(0xFFDDEFFB),
    tertiary: Color(0xFFFF9C8F),
    onTertiary: Color(0xFF4A130B),
    tertiaryContainer: Color(0xFF5C2219),
    onTertiaryContainer: Color(0xFFFFE1DC),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkBg,
    onSurface: Color(0xFFF4F4F6),
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: Color(0xFF0A0A0C),
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: Color(0xFF1E1E24),
    surfaceContainerHigh: AppColors.darkMuted,
    surfaceContainerHighest: AppColors.darkHigh,
    outline: Color(0xFF5A5A63),
    outlineVariant: Color(0xFF26262D),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF4F4F6),
    onInverseSurface: AppColors.ink,
    inversePrimary: AppColors.primary,
  );

  static ThemeData get light => _build(lightScheme);
  static ThemeData get dark => _build(darkScheme);

  static TextStyle? _h(TextStyle? s, FontWeight w) =>
      s?.copyWith(fontFamily: AppFonts.heading, fontWeight: w, letterSpacing: -0.3);

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs, fontFamily: AppFonts.body);
    final t = base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
    final text = t.copyWith(
      displayLarge: _h(t.displayLarge, FontWeight.w800),
      displayMedium: _h(t.displayMedium, FontWeight.w800),
      displaySmall: _h(t.displaySmall, FontWeight.w800),
      headlineLarge: _h(t.headlineLarge, FontWeight.w800),
      headlineMedium: _h(t.headlineMedium, FontWeight.w800),
      headlineSmall: _h(t.headlineSmall, FontWeight.w800),
      titleLarge: _h(t.titleLarge, FontWeight.w800),
      titleMedium: _h(t.titleMedium, FontWeight.w700),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
    );
    final pill = const StadiumBorder();

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 22),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLow,
        indicatorColor: cs.primaryContainer,
        indicatorShape: pill,
        elevation: 0,
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: cs.surfaceContainerLow,
        labelStyle: text.labelLarge?.copyWith(color: cs.onSurface),
        side: BorderSide(color: cs.outlineVariant),
        shape: pill,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: pill,
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          shape: pill,
          side: BorderSide(color: cs.outlineVariant, width: 1.5),
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: pill,
        elevation: 2,
        extendedTextStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHigh,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
