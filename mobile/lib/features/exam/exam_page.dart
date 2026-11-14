import 'dart:async';
import 'package:flutter/material.dart';
import '../../api.dart';
import '../../auth.dart';
import '../../db.dart';
import '../../models.dart';
import '../../core/widgets/empty_state.dart';
import '../../screens/flows.dart';
import '../../screens/quiz_screen.dart' show ResultScreen;

// ============================================================
// Sınav Simülasyonu: not seç → süre belirle → süreli sınav → analiz
// Mevcut "test-olustur" ve "performans" servislerini kullanır.
// ============================================================
class ExamSetupPage extends StatefulWidget {
  const ExamSetupPage({super.key});

  @override
  State<ExamSetupPage> createState() => _ExamSetupPageState();
}

class _ExamSetupPageState extends State<ExamSetupPage> {
  List<DbRow> _notes = [];
  final Set<int> _selected = {};
  double _minutes = 20;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await Repo.notes(Session.userId ?? 0);
    if (!mounted) return;
    setState(() {
      _notes = n;
      _loading = false;
    });
  }

  Future<void> _start() async {
    final uid = Session.userId;
    if (uid == null || _selected.isEmpty) return;
    final chosen = _notes.where((n) => _selected.contains(n['id'] as int)).toList();
    // Seçilen notları eşit pay ile birleştir (servis en fazla 6000 karakter alıyor).
    final share = (5800 / chosen.length).floor();
    final text = chosen.map((n) {
      final c = (n['content'] as String?) ?? '';
      final body = c.length > share ? c.substring(0, share) : c;
      return '## ${(n['title'] as String?) ?? 'Not'}\n$body';
    }).join('\n\n');

    final qs = await withLoader<List<Question>>(
        context, 'Sınav soruları hazırlanıyor...', () => Api.generateTest(text));
    if (qs == null || !mounted) return;
    final now = DateTime.now();
    final title =
        'Deneme Sınavı ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final testId = await Repo.addTest(uid, chosen.first['id'] as int, title, qs);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExamRunPage(testId: testId, questions: qs, minutes: _minutes.round()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sınav Simülasyonu')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: Icons.note_add_outlined,
                      message: 'Sınav oluşturmak için önce Notlar sekmesinden bir ders notu ekle.',
                      compact: false,
                    ),
                  ),
                )
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(children: [
                            Icon(Icons.timer_outlined, color: cs.onPrimaryContainer, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Notlarından gerçek sınav gibi süreli bir deneme oluştur. '
                                'Süre bitince sınav otomatik teslim edilir.',
                                style: TextStyle(color: cs.onPrimaryContainer),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        Text('Süre: ${_minutes.round()} dakika',
                            style: Theme.of(context).textTheme.titleMedium),
                        Slider(
                          value: _minutes,
                          min: 5,
                          max: 60,
                          divisions: 11,
                          label: '${_minutes.round()} dk',
                          onChanged: (v) => setState(() => _minutes = v),
                        ),
                        const SizedBox(height: 8),
                        Text('Konular (bir veya birkaç not seç)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final n in _notes)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CheckboxListTile(
                              value: _selected.contains(n['id'] as int),
                              onChanged: (v) => setState(() {
                                final id = n['id'] as int;
                                v == true ? _selected.add(id) : _selected.remove(id);
                              }),
                              title: Text((n['title'] as String?) ?? 'Not',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text((n['subject_name'] as String?) ?? 'Genel'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty ? null : _start,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_selected.isEmpty
                            ? 'Not seç'
                            : 'Sınavı başlat (${_selected.length} not)'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ),
                  ),
                ]),
    );
  }
}

class ExamRunPage extends StatefulWidget {
  const ExamRunPage({super.key, required this.testId, required this.questions, required this.minutes});
  final int testId;
  final List<Question> questions;
  final int minutes;

  @override
  State<ExamRunPage> createState() => _ExamRunPageState();
}

class _ExamRunPageState extends State<ExamRunPage> {
  late int _left = widget.minutes * 60;
  Timer? _timer;
  int _i = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final q in widget.questions) {
      q.selected = null;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        _timer?.cancel();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Süre doldu, sınav teslim ediliyor.')));
        _submit();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final s = _left < 0 ? 0 : _left;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  int get _answered => widget.questions.where((q) => q.selected != null).length;

  Future<void> _confirmSubmit() async {
    final empty = widget.questions.length - _answered;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sınavı bitir'),
        content: Text(empty > 0
            ? '$empty soru boş. Yine de teslim etmek istiyor musun?'
            : 'Tüm soruları cevapladın. Teslim edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Devam et')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Teslim et')),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    _submitting = true;
    _timer?.cancel();
    final qs = widget.questions;
    for (final q in qs) {
      q.selected ??= 'Boş bırakıldı';
    }
    final result = await withLoader(context, 'Sınavın değerlendiriliyor...', () => Api.evaluate(qs));
    if (!mounted) return;
    if (result == null) {
      _submitting = false;
      for (final q in qs) {
        if (q.selected == 'Boş bırakıldı') q.selected = null;
      }
      return;
    }
    final total = (result['total'] as num).toInt();
    final correct = (result['correct'] as num).toInt();
    final pct = (result['percentage'] as num).toInt();
    final weak = ((result['weak_topics'] ?? []) as List).map((e) => e.toString()).toList();
    await Repo.addResult(Session.userId!, widget.testId, total, correct, pct, weak,
        (result['recommendations'] ?? '').toString());
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => ResultScreen(result: result, questions: qs)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qs = widget.questions;
    final q = qs[_i];
    final urgent = _left <= 60;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Sınavdan çık'),
            content: const Text('Çıkarsan bu deneme kaydedilmez. Emin misin?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Kal')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çık')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Soru ${_i + 1}/${qs.length}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.timer_outlined,
                    size: 18, color: urgent ? cs.onErrorContainer : cs.onSecondaryContainer),
                label: Text(_clock,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: urgent ? cs.onErrorContainer : cs.onSecondaryContainer)),
                backgroundColor: urgent ? cs.errorContainer : cs.secondaryContainer,
                side: BorderSide.none,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: _left / (widget.minutes * 60)),
          ),
        ),
        body: Column(children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: qs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, k) {
                final answered = qs[k].selected != null;
                final current = k == _i;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _i = k),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: current
                        ? cs.primary
                        : (answered ? cs.primaryContainer : cs.surfaceContainerHighest),
                    child: Text('${k + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            color: current
                                ? cs.onPrimary
                                : (answered ? cs.onPrimaryContainer : cs.onSurfaceVariant))),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(q.question, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              for (final o in q.options)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: q.selected == o ? cs.primaryContainer : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => q.selected = o),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Icon(q.selected == o ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: q.selected == o ? cs.primary : cs.outline),
                        const SizedBox(width: 12),
                        Expanded(child: Text(o)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                OutlinedButton(
                  onPressed: _i == 0 ? null : () => setState(() => _i--),
                  child: const Text('Önceki'),
                ),
                const SizedBox(width: 8),
                if (_i < qs.length - 1)
                  OutlinedButton(
                    onPressed: () => setState(() => _i++),
                    child: const Text('Sonraki'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _confirmSubmit,
                  child: Text('Bitir ($_answered/${qs.length})'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
