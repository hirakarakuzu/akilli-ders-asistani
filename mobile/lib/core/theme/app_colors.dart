import 'package:flutter/material.dart';

/// Tüm renkler SADECE burada tanımlanır. Ekranlarda Color(0xFF...) kullanma;
/// Theme.of(context).colorScheme veya AppColors üzerinden eriş.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF174EA6); // Ana renk
  static const electric = Color(0xFF2878F0); // Elektrik mavisi
  static const sky = Color(0xFF66B5FF); // Açık mavi
  static const navy = Color(0xFF101D3A); // Lacivert
  static const ice = Color(0xFFEAF4FF); // Buz mavisi
  static const white = Color(0xFFFFFFFF);

  // Dark mode yüzeyleri (lacivertten türetildi)
  static const navyLow = Color(0xFF15254A);
  static const navyMid = Color(0xFF1B2F5C);
  static const navyHigh = Color(0xFF23396B);

  static const success = Color(0xFF2E9E6B);
  static const warning = Color(0xFFF2A93B);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, electric],
  );

  static const brandGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B3F85), Color(0xFF2268D6)],
  );
}
