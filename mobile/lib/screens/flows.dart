import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../db.dart';
import 'chat_screen.dart';

Future<T?> withLoader<T>(BuildContext context, String message, Future<T> Function() fn) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ]),
      ),
    ),
  );
  try {
    final r = await fn();
    nav.pop();
    return r;
  } on ApiException catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  } catch (_) {
    nav.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Beklenmeyen bir hata oluştu.')));
    return null;
  }
}

Future<int?> addSubjectDialog(BuildContext context) async {
  final c = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Yeni ders'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Ders adı')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Ekle')),
      ],
    ),
  );
  if (name == null || name.isEmpty) return null;
  return Repo.addSubject(Session.userId!, name);
}

Future<int?> pickSubject(BuildContext context) async {
  final subjects = await Repo.subjects(Session.userId!);
  if (!context.mounted) return null;
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Ders seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          for (final s in subjects)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(s['name'] as String),
              onTap: () => Navigator.pop(ctx, s['id'] as int),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Yeni ders ekle'),
            onTap: () async {
              final id = await addSubjectDialog(ctx);
              if (ctx.mounted && id != null) Navigator.pop(ctx, id);
            },
          ),
        ]),
      ),
    ),
  );
}

Future<void> startNewChat(BuildContext context) async {
  final sid = await pickSubject(context);
  if (sid == null || !context.mounted) return;
  final id = await Repo.createConversation(Session.userId!, sid, 'Yeni sohbet');
  if (!context.mounted) return;
  await Navigator.push(context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: 'Yeni sohbet')));
}
