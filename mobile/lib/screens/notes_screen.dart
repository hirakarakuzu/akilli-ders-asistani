import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../api.dart';
import '../auth.dart';
import '../db.dart';
import '../widgets.dart';
import 'flows.dart';
import 'quiz_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<DbRow> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await Repo.notes(Session.userId!);
    if (!mounted) return;
    setState(() {
      notes = n;
      loading = false;
    });
  }

  Future<void> _summarize(DbRow n) async {
    final summary = await withLoader(context, 'Özet hazırlanıyor...', () => Api.summarize(n['content'] as String));
    if (summary == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n['title'] as String),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: MarkdownBody(data: summary, selectable: true))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  Future<void> _makeTest(DbRow n) async {
    final qs = await withLoader(context, 'Test hazırlanıyor... (30-60 sn sürebilir)', () => Api.generateTest(n['content'] as String));
    if (qs == null || !mounted) return;
    final title = '${n['title']} testi';
    final id = await Repo.addTest(Session.userId!, n['id'] as int, title, qs);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(testId: id, title: title, questions: qs)));
  }

  Future<void> _delete(DbRow n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await Repo.deleteNote(Session.userId!, n['id'] as int);
      _load();
    }
  }

  void _view(DbRow n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n['title'] as String),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: SelectableText(n['content'] as String))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ders notları')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddNoteScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Not ekle'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? const EmptyState(icon: Icons.note_alt_outlined, text: 'Henüz not yok.\nMetin yaz veya TXT dosyası yükle.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: notes.length,
                  itemBuilder: (_, i) {
                    final n = notes[i];
                    return AppCard(
                      onTap: () => _view(n),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('${n['subject_name'] ?? 'Genel'} • ${fmtDate(n['created_at'] as String)}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                        const SizedBox(height: 8),
                        Text(n['content'] as String, maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          TextButton.icon(onPressed: () => _summarize(n), icon: const Icon(Icons.summarize_outlined), label: const Text('Özetle')),
                          TextButton.icon(onPressed: () => _makeTest(n), icon: const Icon(Icons.quiz_outlined), label: const Text('Test')),
                          const Spacer(),
                          IconButton(onPressed: () => _delete(n), icon: const Icon(Icons.delete_outline)),
                        ]),
                      ]),
                    );
                  },
                ),
    );
  }
}

class AddNoteScreen extends StatefulWidget {
  const AddNoteScreen({super.key});
  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  List<DbRow> subjects = [];
  int? subjectId;

  @override
  void initState() {
    super.initState();
    Repo.subjects(Session.userId!).then((s) {
      if (!mounted) return;
      setState(() {
        subjects = s;
        if (s.isNotEmpty) subjectId = s.first['id'] as int;
      });
    });
  }

  Future<void> _pickTxt() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt'], withData: true);
      if (res == null) return;
      final f = res.files.single;
      if (f.bytes == null) throw Exception('empty');
      final text = utf8.decode(f.bytes!, allowMalformed: true);
      if (text.trim().isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya boş görünüyor.')));
        return;
      }
      setState(() {
        _content.text = text;
        if (_title.text.trim().isEmpty) _title.text = f.name.replaceAll('.txt', '');
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı. Lütfen geçerli bir TXT dosyası seçin.')));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await Repo.addNote(Session.userId!, subjectId, _title.text.trim(), _content.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni not')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Başlık', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Başlık girin' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: subjectId,
            decoration: const InputDecoration(labelText: 'Ders', border: OutlineInputBorder()),
            items: [for (final s in subjects) DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String))],
            onChanged: (v) => setState(() => subjectId = v),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _pickTxt, icon: const Icon(Icons.upload_file), label: const Text('TXT dosyası yükle')),
          const SizedBox(height: 14),
          TextFormField(
            controller: _content,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(labelText: 'Ders notu', alignLabelWithHint: true, border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().length < 20) ? 'Not en az 20 karakter olmalı' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Kaydet')),
        ]),
      ),
    );
  }
}
