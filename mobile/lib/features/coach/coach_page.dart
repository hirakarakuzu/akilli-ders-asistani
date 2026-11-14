import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api.dart';
import '../../auth.dart';
import '../../core/widgets/empty_state.dart';
import '../progress/progress_repo.dart';

/// AI Koç: test sonuçları, zayıf konular ve flashcard durumundan kişisel öneri üretir.
/// Mevcut "chat" servisini kullanır.
class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  ProgressData? _data;
  String? _advice;
  String? _adviceDate;
  String? _error;
  bool _loading = true;
  bool _asking = false;
  final _q = TextEditingController();

  static const _quick = [
    'Bu hafta neye odaklanmalıyım?',
    'Zayıf konularımı nasıl kapatırım?',
    'Sınava 1 hafta kaldı, nasıl çalışayım?',
    'Motivasyonum düşük, ne yapmalıyım?',
  ];

  String get _key => 'coach_advice_${Session.userId ?? 0}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ProgressRepo.load(Session.userId ?? 0);
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _data = d;
      _advice = p.getString(_key);
      _adviceDate = p.getString('${_key}_date');
      _loading = false;
    });
  }

  String _profile(ProgressData d) {
    final b = StringBuffer();
    b.writeln('Öğrenci verileri:');
    b.writeln('- Kayıtlı not sayısı: ${d.notes}');
    b.writeln('- Çözülen test: ${d.results}, ortalama başarı: %${d.avg}, en iyi: %${d.best}');
    if (d.trend.isNotEmpty) {
      b.writeln('- Son test puanları (eskiden yeniye): ${d.trend.map((t) => t.percentage).join(', ')}');
    }
    if (d.subjects.isNotEmpty) {
      b.writeln('- Ders bazlı ortalamalar: ${d.subjects.map((s) => '${s.name} %${s.avg}').join(', ')}');
    }
    if (d.weakTopics.isNotEmpty) {
      b.writeln('- En sık yanlış yapılan konular: '
          '${d.weakTopics.map((t) => '${t.topic} (${t.count} kez)').join(', ')}');
    }
    if (d.cardsTotal > 0) {
      b.writeln('- Flashcard: ${d.cardsTotal} kartın ${d.cardsLearned} tanesi öğrenildi, '
          '${d.cardsDue} kart tekrar bekliyor');
    }
    return b.toString();
  }

  Future<void> _ask(String question) async {
    final d = _data;
    if (d == null || _asking) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _asking = true;
      _error = null;
    });
    final prompt = 'Sen öğrencinin kişisel çalışma koçusun. Aşağıdaki verilere dayanarak Türkçe, '
        'samimi ama kısa yanıt ver. Genel tavsiye yerine verideki derslere ve konulara özel, '
        'uygulanabilir öneriler yaz. Önce 1-2 cümlelik durum değerlendirmesi, sonra "Bugün yap" ve '
        '"Bu hafta yap" başlıkları altında madde madde öneriler ver.\n\n'
        '${_profile(d)}\nÖğrencinin sorusu: $question';
    try {
      final reply = await Api.chat(prompt);
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final date = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      await p.setString(_key, reply);
      await p.setString('${_key}_date', date);
      if (!mounted) return;
      setState(() {
        _advice = reply;
        _adviceDate = date;
      });
      _q.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Beklenmeyen bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Koç')),
      body: _loading || d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.psychology_outlined, color: cs.onPrimary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Kişisel koçun', style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                        const SizedBox(height: 4),
                        Text(
                          d.results == 0
                              ? 'Henüz test çözmedin. Birkaç test çözersen önerilerim çok daha isabetli olur.'
                              : '${d.results} test, ortalama %${d.avg}'
                                  '${d.weakTopics.isNotEmpty ? ' · en zor konu: ${d.weakTopics.first.topic}' : ''}',
                          style: TextStyle(color: cs.onPrimaryContainer),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _quick)
                    ActionChip(
                      label: Text(s),
                      onPressed: _asking ? null : () => _ask(s),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _q,
                  enabled: !_asking,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => v.trim().isEmpty ? null : _ask(v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Koçuna bir şey sor...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _asking
                          ? null
                          : () => _q.text.trim().isEmpty ? null : _ask(_q.text.trim()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_asking)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Koçun verilerini inceliyor...'),
                    ]),
                  )
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: cs.error))
                else if (_advice != null)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.lightbulb_outline, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Koçunun önerisi', style: tt.titleMedium)),
                          if (_adviceDate != null)
                            Text(_adviceDate!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ]),
                        const Divider(height: 24),
                        MarkdownBody(data: _advice!, selectable: true),
                      ]),
                    ),
                  )
                else
                  EmptyState(
                    icon: Icons.tips_and_updates_outlined,
                    message: 'Yukarıdaki sorulardan birine dokun, sana özel bir plan çıkarayım.',
                    actionLabel: 'Bana öneri ver',
                    onAction: () => _ask(_quick.first),
                  ),
              ],
            ),
    );
  }
}
