import 'package:flutter/material.dart';
import '../../auth.dart';
import '../../core/widgets/empty_state.dart';
import 'progress_repo.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late Future<ProgressData> _future;

  @override
  void initState() {
    super.initState();
    _future = ProgressRepo.load(Session.userId ?? 0);
  }

  Future<void> _reload() async {
    final f = ProgressRepo.load(Session.userId ?? 0);
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başarı Haritası')),
      body: FutureBuilder<ProgressData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  message: 'Veriler yüklenemedi.',
                  actionLabel: 'Tekrar dene',
                  onAction: _reload,
                  compact: false,
                ),
              ),
            );
          }
          final p = snap.data!;
          if (p.results == 0 && p.cardsTotal == 0) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  message:
                      'Henüz analiz edilecek veri yok.\nBir test çöz ya da flashcard çalış; haritan burada oluşacak.',
                  compact: false,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: _Stat(label: 'Ortalama', value: '%${p.avg}', icon: Icons.percent)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(label: 'En iyi', value: '%${p.best}', icon: Icons.emoji_events_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(label: 'Test', value: '${p.results}', icon: Icons.quiz_outlined)),
                ]),
                if (p.trend.isNotEmpty) ...[
                  const _Title('Son testlerin'),
                  _Panel(child: _TrendChart(points: p.trend)),
                ],
                if (p.subjects.isNotEmpty) ...[
                  const _Title('Ders bazlı başarı'),
                  _Panel(
                    child: Column(children: [
                      for (final s in p.subjects) _ScoreBar(label: s.name, value: s.avg, note: '${s.count} test'),
                    ]),
                  ),
                ],
                if (p.weakTopics.isNotEmpty) ...[
                  const _Title('En çok zorlandığın konular'),
                  _Panel(
                    child: Column(children: [
                      for (final t in p.weakTopics) _TopicRow(topic: t, max: p.weakTopics.first.count),
                    ]),
                  ),
                ],
                if (p.cardsTotal > 0) ...[
                  const _Title('Flashcard'),
                  _Panel(
                    child: _ScoreBar(
                      label: '${p.cardsLearned}/${p.cardsTotal} kart öğrenildi',
                      value: (p.cardsLearned * 100 / p.cardsTotal).round(),
                      note: p.cardsDue > 0 ? '${p.cardsDue} kart tekrar bekliyor' : 'Tekrarlar tamam',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: cs.onPrimaryContainer, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: cs.onPrimaryContainer)),
      ]),
    );
  }
}

Color scoreColor(ColorScheme cs, int v) =>
    v >= 70 ? cs.primary : (v >= 50 ? cs.tertiary : cs.error);

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value, this.note});
  final String label;
  final int value;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('%$value', style: TextStyle(fontWeight: FontWeight.w700, color: scoreColor(cs, value))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            color: scoreColor(cs, value),
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(note!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.max});
  final TopicCount topic;
  final int max;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 3, child: Text(topic.topic, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : topic.count / max,
              minHeight: 8,
              color: cs.error,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${topic.count}×', style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<ResultPoint> points;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Tooltip(
                message: '${p.title}: %${p.percentage}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${p.percentage}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Container(
                        height: 4 + 110 * (p.percentage.clamp(0, 100) / 100),
                        decoration: BoxDecoration(
                          color: scoreColor(cs, p.percentage),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
