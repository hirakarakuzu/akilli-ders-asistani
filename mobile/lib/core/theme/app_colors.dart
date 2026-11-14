import 'package:flutter/material.dart';

/// Tüm renkler SADECE burada tanımlanır. Ekranlarda Color(0xFF...) kullanma;
/// Theme.of(context).colorScheme veya AppColors üzerinden eriş.
///
/// Bilge'nin paleti, Lezzet Atlası ile aynı pastel aileden gelir (mercan, kehribar,
/// adaçayı, gök mavisi, lavanta). Bilge'nin imza rengi lavanta → gök mavisi geçişidir.
class AppColors {
  AppColors._();

  // ---- İmza pastel aile ----
  static const lavender = Color(0xFF9B7FD4);
  static const sky = Color(0xFF4DA8DA);
  static const coral = Color(0xFFFF6B5B);
  static const amber = Color(0xFFFFB347);
  static const sage = Color(0xFF6BCB77);

  /// Ders, araç ve istatistik kartlarında sırayla kullanılan renkler.
  static const pastels = [lavender, sky, coral, amber, sage];

  // ---- Ana renkler ----
  static const primary = Color(0xFF7354CC); // koyu lavanta: beyaz yazı okunur
  static const electric = Color(0xFF3D8FD1); // koyu gök mavisi
  static const ink = Color(0xFF18181B); // ana yazı
  static const inkSoft = Color(0xFF52525B); // ikincil yazı
  static const muted = Color(0xFFA1A1AA);
  static const white = Color(0xFFFFFFFF);
  static const ice = Color(0xFFF4F0FF); // lavanta tonlu açık zemin
  static const bg = Color(0xFFFAFAFC);

  // ---- Koyu tema yüzeyleri ----
  static const darkBg = Color(0xFF0E0E11);
  static const darkSurface = Color(0xFF18181D);
  static const darkMuted = Color(0xFF222228);
  static const darkHigh = Color(0xFF2C2C34);

  static const success = Color(0xFF3FA552);
  static const warning = Color(0xFFE59A2F);

  /// Butonlar, sohbet balonu ve logo için imza geçişi.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF5B6EE1)],
  );

  static const brandGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5E43B0), Color(0xFF4655C4)],
  );

  /// Karşılama kartı ve giriş ekranı arka planı (lavanta → şeftali → gök).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3EDFF), Color(0xFFFFF2EA), Color(0xFFEAF4FF)],
  );

  static const heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1934), Color(0xFF221A1D), Color(0xFF16202E)],
  );

  /// Bir isim için her zaman aynı pastel rengi döndürür (ders renkleri).
  static Color colorFor(String name) {
    var h = 0;
    for (final c in name.toLowerCase().codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return pastels[h % pastels.length];
  }
}
