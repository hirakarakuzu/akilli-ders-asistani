import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../api.dart';
import '../auth.dart';
import '../db.dart';
import '../models.dart';
import '../widgets.dart';
import 'flows.dart';

class QuizScreen extends StatefulWidget {
  final int testId;
  final String title;
  final List<Question> questions;
  const QuizScreen({super.key, required this.testId, required this.title, required this.questions});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    for (final q in widget.questions) {
      q.selected = null; // her çözümde sıfırla
    }
  }

  Future<void> _finish() async {
    final qs = widget.questions;
    if (qs.any((q) => q.selected == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm soruları cevaplayın.')));
      return;
    }
    final result = await withLoader(context, 'Sonuçlar analiz ediliyor...', () => Api.evaluate(qs));
    if (result == null || !mounted) return;
    final total = (result['total'] as num).toInt();
    final correct = (result['correct'] as num).toInt();
    final pct = (result['percentage'] as num).toInt();
    final weak = ((result['weak_topics'] ?? []) as List).map((e) => e.toString()).toList();
    await Repo.addResult(Session.userId!, widget.testId, total, correct, pct, weak, (result['recommendations'] ?? '').toString());
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(result: result, questions: qs)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qs = widget.questions;
    final q = qs[i];
    final last = i == qs.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${i + 1} / ${qs.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (i + 1) / qs.length),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(child: Text(q.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            for (final o in q.options)
              AppCard(
                onTap: () => setState(() => q.selected = o),
                child: Row(children: [
                  Icon(q.selected == o ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: q.selected == o ? cs.primary : cs.outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(o)),
                ]),
              ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              if (i > 0) OutlinedButton(onPressed: () => setState(() => i--), child: const Text('Geri')),
              const Spacer(),
              FilledButton(
                onPressed: q.selected == null ? null : (last ? _finish : () => setState(() => i++)),
                child: Text(last ? 'Testi bitir' : 'İleri'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final List<Question> questions;
  const ResultScreen({super.key, required this.result, required this.questions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (result['percentage'] as num).toInt();
    final correct = (result['correct'] as num).toInt();
    final wrong = (result['wrong'] as num).toInt();
    final total = (result['total'] as num).toInt();
    final weak = ((result['weak_topics'] ?? []) as List).map((e) => e.toString()).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Test sonucu')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: pct / 100, strokeWidth: 10)),
                Text('%$pct', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('$total sorudan $correct doğru, $wrong yanlış', style: const TextStyle(fontSize: 16)),
          ]),
        ),
        if (weak.isNotEmpty) ...[
          const SectionTitle('Eksik konular'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final w in weak) Chip(label: Text(w))]),
        ],
        const SectionTitle('Kişiselleştirilmiş çalışma önerileri'),
        AppCard(child: MarkdownBody(data: (result['recommendations'] ?? '').toString(), selectable: true)),
        const SectionTitle('Soru incelemesi'),
        for (final q in questions)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(q.selected == q.correct ? Icons.check_circle : Icons.cancel,
                    color: q.selected == q.correct ? Colors.green : cs.error),
                const SizedBox(width: 8),
                Expanded(child: Text(q.question, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Text('Cevabın: ${q.selected}'),
              Text('Doğru cevap: ${q.correct}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (q.explanation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(q.explanation, style: TextStyle(color: cs.outline)),
              ],
            ]),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
      ]),
    );
  }
}
