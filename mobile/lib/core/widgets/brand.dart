import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bilge'nin baykuş çizimi (Android simgesiyle aynı).
const owlAsset = 'assets/brand/owl.png';

/// Bilge logosu: geçişli yuvarlak kare içinde baykuş + isteğe bağlı yazı.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: size * .35, offset: Offset(0, size * .12)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: Image.asset(owlAsset, filterQuality: FilterQuality.medium),
        ),
      ),
      if (showName) ...[
        SizedBox(width: size * 0.28),
        Text('Bilge',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.62,
              letterSpacing: -0.5,
              color: cs.onSurface,
            )),
      ],
    ]);
  }
}

/// Bulanık pastel lekeler: karşılama kartı ve giriş ekranının arka planı.
class SoftBlobs extends StatelessWidget {
  const SoftBlobs({super.key, this.intensity = 1});
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = (dark ? 0.22 : 0.30) * intensity;
    Widget blob(Color c, double s) => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(color: c.withValues(alpha: a), shape: BoxShape.circle),
        );
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(top: -60, right: -40, child: blob(AppColors.lavender, 200)),
          Positioned(bottom: -70, left: -50, child: blob(AppColors.coral, 170)),
          Positioned(top: 30, left: 120, child: blob(AppColors.sky, 120)),
        ]),
      ),
    );
  }
}

/// Lezzet Atlası'ndaki gibi noktalı küçük rozet ("● 3 gün seri").
class SoftBadge extends StatelessWidget {
  const SoftBadge({super.key, required this.text, this.color = AppColors.coral});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .30)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: Color.lerp(color, Colors.black, Theme.of(context).brightness == Brightness.dark ? 0 : .35),
            )),
      ]),
    );
  }
}

/// Pastel geçişli büyük kart (karşılama alanı).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: dark ? AppColors.heroGradientDark : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned.fill(child: SoftBlobs()),
        Padding(padding: const EdgeInsets.all(22), child: child),
      ]),
    );
  }
}

/// Pastel bir rengin üzerinde ikon (araç ve istatistik kartları için).
class PastelIcon extends StatelessWidget {
  const PastelIcon({super.key, required this.icon, required this.color, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .16),
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(icon, size: size * .52, color: dark ? color : Color.lerp(color, Colors.black, .28)),
    );
  }
}

/// Lezzet Atlası'ndaki gibi geçişli, gölgeli hap buton.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.onPressed, required this.child, this.icon});
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: SizedBox(
              height: 52,
              child: Center(
                child: DefaultTextStyle(
                  style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.white),
                  child: IconTheme(
                    data: const IconThemeData(color: AppColors.white, size: 20),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                      child,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
