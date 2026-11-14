import 'package:flutter/material.dart';

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: cs.onPrimaryContainer),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Pzt..Paz, değerler 0-100 (başarı %).
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.values});
  final List<double> values;
  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (i < values.length ? values[i] : 0).clamp(0, 100) / 100),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Container(
                    width: 18,
                    height: 4 + 76 * v,
                    decoration: BoxDecoration(
                      color: v == 0 ? cs.surfaceContainerHigh : cs.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_days[i], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
        ],
      ),
    );
  }
}
