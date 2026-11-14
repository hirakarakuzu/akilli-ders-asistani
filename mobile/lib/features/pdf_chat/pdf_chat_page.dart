import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../api.dart';
import '../../auth.dart';
import '../../core/utils/activity.dart';
import '../../db.dart';
import '../../core/widgets/empty_state.dart';

/// Arka planda (ayrı isolate) PDF metnini çıkarır.
Map<String, Object> _extractPdf(Uint8List bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  final pages = doc.pages.count;
  final text = PdfTextExtractor(doc).extractText();
  doc.dispose();
  return {'pages': pages, 'text': text};
}

class _Msg {
  _Msg(this.user, this.text, {this.error = false});
  final bool user;
  final String text;
  final bool error;
}

class PdfChatPage extends StatefulWidget {
  const PdfChatPage({super.key});

  @override
  State<PdfChatPage> createState() => _PdfChatPageState();
}

class _PdfChatPageState extends State<PdfChatPage> {
  String? _name;
  String _text = '';
  int _pages = 0;
  List<String> _chunks = [];
  bool _reading = false;
  bool _thinking = false;
  final List<_Msg> _msgs = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = res?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() => _reading = true);
    try {
      final r = await compute(_extractPdf, bytes);
      final text = (r['text'] as String).replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (!mounted) return;
      if (text.length < 50) {
        setState(() => _reading = false);
        _snack('Bu PDF\'den metin okunamadı. Taranmış (resim) PDF olabilir.');
        return;
      }
      setState(() {
        _name = file.name;
        _text = text;
        _pages = r['pages'] as int;
        _chunks = _split(text);
        _msgs
          ..clear()
          ..add(_Msg(false,
              '**${file.name}** hazır ($_pages sayfa). Bu belge hakkında istediğini sorabilirsin.'));
        _reading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _reading = false);
      _snack('PDF açılamadı. Dosya şifreli veya bozuk olabilir.');
    }
  }

  /// Metni ~800 karakterlik parçalara böler.
  List<String> _split(String text) {
    final parts = text.split(RegExp(r'\n\s*\n|\n'));
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (buf.length + t.length > 800 && buf.isNotEmpty) {
        chunks.add(buf.toString());
        buf.clear();
      }
      buf.writeln(t);
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  /// Soruyla en çok ortak kelimesi olan parçaları seçer (en fazla ~3000 karakter).
  String _context(String question) {
    final words = _norm(question)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2)
        .map((w) => w.length > 5 ? w.substring(0, 5) : w) // basit kök: ekleri at
        .toSet();
    final scored = <MapEntry<int, int>>[];
    for (var i = 0; i < _chunks.length; i++) {
      final c = _norm(_chunks[i]);
      var s = 0;
      for (final w in words) {
        if (c.contains(w)) s++;
      }
      scored.add(MapEntry(i, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final picked = <int>[];
    var len = 0;
    for (final e in scored) {
      if (len > 3000) break;
      if (e.value == 0 && picked.isNotEmpty) break;
      picked.add(e.key);
      len += _chunks[e.key].length;
    }
    if (picked.isEmpty) return _text.length > 3000 ? _text.substring(0, 3000) : _text;
    picked.sort();
    return picked.map((i) => _chunks[i]).join('\n...\n');
  }

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, q));
      _thinking = true;
    });
    _toBottom();
    final prompt = 'Aşağıdaki BELGE bölümlerine dayanarak soruyu Türkçe yanıtla. '
        'Cevap belgede yoksa "Bu bilgi belgede yer almıyor." de, uydurma.\n\n'
        'BELGE ($_name):\n${_context(q)}\n\nSORU: $q';
    try {
      final reply = await Api.chat(prompt);
      await ActivityLog.add(Session.userId, 90, 'pdf');
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(false, reply)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(false, e.message, error: true)));
    } catch (_) {
      if (mounted) setState(() => _msgs.add(_Msg(false, 'Beklenmeyen bir hata oluştu.', error: true)));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  Future<void> _summarize() async {
    if (_thinking) return;
    setState(() {
      _msgs.add(_Msg(true, 'Bu belgeyi özetle'));
      _thinking = true;
    });
    _toBottom();
    try {
      final s = await Api.summarize(_text);
      if (mounted) setState(() => _msgs.add(_Msg(false, s)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(false, e.message, error: true)));
    } catch (_) {
      if (mounted) setState(() => _msgs.add(_Msg(false, 'Beklenmeyen bir hata oluştu.', error: true)));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  Future<void> _saveAsNote() async {
    final uid = Session.userId;
    if (uid == null || _name == null) return;
    final title = _name!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    await Repo.addNote(uid, null, title, _text);
    if (mounted) _snack('"$title" notlarına kaydedildi. Artık ondan test ve flashcard oluşturabilirsin.');
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_name ?? 'PDF ile Konuş', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_name != null) ...[
            IconButton(tooltip: 'Notlarıma kaydet', icon: const Icon(Icons.save_alt), onPressed: _saveAsNote),
            IconButton(tooltip: 'Başka PDF seç', icon: const Icon(Icons.upload_file), onPressed: _reading ? null : _pick),
          ],
        ],
      ),
      body: _reading
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('PDF okunuyor...'),
              ]),
            )
          : _name == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: Icons.picture_as_pdf_outlined,
                      message: 'Bir ders PDF\'i seç; özetleyeyim ve içeriği hakkındaki sorularını yanıtlayayım.',
                      actionLabel: 'PDF seç',
                      onAction: _pick,
                      compact: false,
                    ),
                  ),
                )
              : Column(children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _msgs.length + (_thinking ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _msgs.length) {
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          );
                        }
                        final m = _msgs[i];
                        return Align(
                          alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            decoration: BoxDecoration(
                              color: m.user
                                  ? cs.primary
                                  : (m.error ? cs.errorContainer : cs.surfaceContainerHigh),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: m.user
                                ? Text(m.text, style: TextStyle(color: cs.onPrimary))
                                : MarkdownBody(data: m.text, selectable: true),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_msgs.length <= 1)
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          ActionChip(label: const Text('Özetle'), onPressed: _summarize),
                          const SizedBox(width: 8),
                          ActionChip(
                              label: const Text('Ana kavramlar neler?'),
                              onPressed: () => _send('Bu belgedeki ana kavramlar nelerdir? Kısaca açıkla.')),
                          const SizedBox(width: 8),
                          ActionChip(
                              label: const Text('Sınavda ne çıkar?'),
                              onPressed: () => _send('Bu belgeden sınavda çıkabilecek 5 önemli nokta nedir?')),
                        ],
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(hintText: 'Belgeye bir soru sor...'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _thinking ? null : () => _send(),
                          icon: const Icon(Icons.send),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}
