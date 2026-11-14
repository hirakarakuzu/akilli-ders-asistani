import 'package:flutter/material.dart';
import '../auth.dart';
import '../db.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'flows.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<DbRow> convs = [];
  List<DbRow> subjects = [];
  int? filter;
  bool loading = true;
  String q = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = Session.userId!;
    final s = await Repo.subjects(uid);
    final c = await Repo.conversations(uid, subjectId: filter);
    if (!mounted) return;
    setState(() {
      subjects = s;
      convs = c;
      loading = false;
    });
  }

  Future<bool> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Sohbet silinsin mi?'),
        content: const Text('Bu sohbetteki tüm mesajlar silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(DbRow c) async {
    if (await _confirm()) {
      await Repo.deleteConversation(Session.userId!, c['id'] as int);
      _load();
    }
  }

  Future<void> _newChat() async {
    await startNewChat(context);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = q.isEmpty
        ? convs
        : convs.where((c) => (c['title'] as String).toLowerCase().contains(q.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sohbetler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.add),
        label: const Text('Yeni sohbet'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Sohbetlerde ara',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => q = '');
                      }),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Tümü'),
                  selected: filter == null,
                  showCheckmark: false,
                  onSelected: (_) {
                    filter = null;
                    _load();
                  },
                ),
              ),
              for (final s in subjects)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s['name'] as String),
                    selected: filter == s['id'],
                    showCheckmark: false,
                    onSelected: (_) {
                      filter = s['id'] as int;
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const SkeletonList()
              : convs.isEmpty
                  ? EmptyState(
                      icon: Icons.chat_bubble_outline,
                      text: 'Henüz sohbet yok.\nYeni sohbet başlatarak asistana soru sor.',
                      actionLabel: 'Yeni sohbet',
                      onAction: _newChat,
                    )
                  : shown.isEmpty
                      ? const EmptyState(icon: Icons.search_off, text: 'Aramayla eşleşen sohbet bulunamadı.')
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                            itemCount: shown.length,
                            itemBuilder: (_, i) {
                              final c = shown[i];
                              return FadeSlideIn(
                                index: i,
                                child: Dismissible(
                                  key: ValueKey('conv_${c['id']}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) => _confirm(),
                                  onDismissed: (_) async {
                                    setState(() => convs.removeWhere((x) => x['id'] == c['id']));
                                    await Repo.deleteConversation(Session.userId!, c['id'] as int);
                                    _load();
                                  },
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.only(right: 24),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                                  ),
                                  child: AppCard(
                                    onTap: () async {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                  conversationId: c['id'] as int, title: c['title'] as String)));
                                      _load();
                                    },
                                    child: Row(children: [
                                      CircleAvatar(
                                        backgroundColor: cs.primaryContainer,
                                        child: Icon(Icons.chat_bubble_outline, color: cs.onPrimaryContainer, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(c['title'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                                              child: Text('${c['subject_name'] ?? 'Genel'}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: cs.onPrimaryContainer)),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(fmtDate(c['created_at'] as String),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                            ),
                                          ]),
                                        ]),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
                                        tooltip: 'Sil',
                                        onPressed: () => _delete(c),
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}
