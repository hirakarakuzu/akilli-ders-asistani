import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../auth.dart';
import '../../db.dart';
import '../../core/widgets/empty_state.dart';
import 'flashcard_api.dart';
import 'flashcard_db.dart';

// ============================================================
// 1) Deste listesi
// ============================================================
class FlashcardPage extends StatefulWidget {
  const FlashcardPage({super.key});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  late Future<List<FcDeck>> _future;

  int get _uid => Session.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _future = FlashcardDb.decks(_uid);
  }

  Future<void> _reload() async {
    final f = FlashcardDb.decks(_uid);
    setState(() => _future = f);
    await f;
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FlashcardCreatePage()),
    );
    if (created == true) _reload();
  }

  Future<void> _study(FcDeck deck, {bool all = false}) async {
    if (!all && deck.due == 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Tekrar bekleyen kart yok'),
          content: const Text('Bu destedeki kartların hepsi şimdilik tamam. Yine de tüm kartları çalışmak ister misin?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tümünü çalış')),
          ],
        ),
      );
      if (ok != true) return;
      all = true;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FlashcardStudyPage(deck: deck, all: all)),
    );
    _reload();
  }

  Future<void> _menu(FcDeck deck, String action) async {
    switch (action) {
      case 'all':
        _study(deck, all: true);
      case 'reset':
        await FlashcardDb.resetDeck(deck.id);
        _reload();
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Deste silinsin mi?'),
            content: Text('"${deck.title}" ve içindeki ${deck.total} kart silinecek.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
            ],
          ),
        );
        if (ok == true) {
          await FlashcardDb.deleteDeck(_uid, deck.id);
          _reload();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Yeni deste'),
      ),
      body: FutureBuilder<List<FcDeck>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.error_outline,
                message: 'Desteler yüklenemedi.',
                actionLabel: 'Tekrar dene',
                onAction: _reload,
                compact: false,
              ),
            );
          }
          final decks = snap.data ?? [];
          if (decks.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: EmptyState(
                  icon: Icons.style_outlined,
                  message: 'Henüz desten yok.\nNotlarından yapay zekâ ile bilgi kartları oluştur.',
                  actionLabel: 'İlk desteni oluştur',
                  onAction: _create,
                  compact: false,
                ),
              ),
            );
          }
          final totalDue = decks.fold<int>(0, (a, d) => a + d.due);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _SummaryBanner(due: totalDue, decks: decks.length),
                const SizedBox(height: 12),
                for (final d in decks)
                  _DeckCard(
                    deck: d,
                    onTap: () => _study(d),
                    onMenu: (a) => _menu(d, a),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.due, required this.decks});
  final int due;
  final int decks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_outlined, color: cs.onPrimaryContainer, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              due > 0
                  ? 'Bugün $due kart tekrar bekliyor'
                  : 'Bugünlük tekrarların bitti, harika!',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
          ),
          Text('$decks deste',
              style: TextStyle(color: cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.onTap, required this.onMenu});
  final FcDeck deck;
  final VoidCallback onTap;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Icon(Icons.style, color: cs.onSecondaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deck.title,
                            style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${deck.total} kart',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (deck.due > 0)
                    Chip(
                      label: Text('${deck.due} tekrar'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.tertiaryContainer,
                      labelStyle: TextStyle(color: cs.onTertiaryContainer),
                      side: BorderSide.none,
                    ),
                  PopupMenuButton<String>(
                    onSelected: onMenu,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'all', child: Text('Tüm kartları çalış')),
                      PopupMenuItem(value: 'reset', child: Text('İlerlemeyi sıfırla')),
                      PopupMenuItem(value: 'delete', child: Text('Desteyi sil')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: deck.progress,
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${deck.learned}/${deck.total} öğrenildi',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 2) Yeni deste oluşturma
// ============================================================
class FlashcardCreatePage extends StatefulWidget {
  const FlashcardCreatePage({super.key});

  @override
  State<FlashcardCreatePage> createState() => _FlashcardCreatePageState();
}

class _FlashcardCreatePageState extends State<FlashcardCreatePage> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  double _count = 10;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<Map<String, String>>? _preview;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickNote() async {
    final uid = Session.userId;
    if (uid == null) return;
    final notes = await Repo.notes(uid);
    if (!mounted) return;
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Henüz kayıtlı notun yok. Metni elle yapıştırabilirsin.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<DbRow>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Not seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              for (final n in notes)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text((n['title'] as String?) ?? 'Not',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text((n['subject_name'] as String?) ?? 'Genel'),
                  onTap: () => Navigator.pop(c, n),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _text.text = (picked['content'] as String?) ?? '';
      if (_title.text.trim().isEmpty) _title.text = (picked['title'] as String?) ?? '';
    });
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    if (_text.text.trim().length < 50) {
      setState(() => _error = 'Kart üretmek için en az birkaç cümlelik bir not gerekli.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await FlashcardApi.generate(_text.text, count: _count.round());
      if (!mounted) return;
      setState(() => _preview = cards);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final cards = _preview;
    final uid = Session.userId;
    if (cards == null || cards.isEmpty || uid == null) return;
    setState(() => _saving = true);
    final title = _title.text.trim().isEmpty ? 'Yeni deste' : _title.text.trim();
    try {
      await FlashcardDb.createDeck(uid, title, cards);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Deste kaydedilemedi. Tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_preview == null ? 'Yeni deste' : 'Kartları kontrol et')),
      body: _preview == null ? _form(context) : _previewList(context),
    );
  }

  Widget _form(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Deste adı',
            hintText: 'Örn. Veri Yapıları – Ağaçlar',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickNote,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Notlarımdan seç'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 8,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Ders notu',
            hintText: 'Notunu buraya yapıştır veya yukarıdan seç',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('Kart sayısı: ${_count.round()}', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: _count,
          min: 5,
          max: 20,
          divisions: 15,
          label: '${_count.round()}',
          onChanged: _loading ? null : (v) => setState(() => _count = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: _loading
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Kartlar hazırlanıyor...' : 'Yapay zekâ ile kart oluştur'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Bu işlem notun uzunluğuna göre 1-2 dakika sürebilir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
      ],
    );
  }

  Widget _previewList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cards = _preview!;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final c = cards[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: cs.primaryContainer,
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
                  ),
                  title: Text(c['front']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(c['back']!),
                  ),
                  trailing: IconButton(
                    tooltip: 'Kartı çıkar',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => cards.removeAt(i)),
                  ),
                ),
              );
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => setState(() => _preview = null),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text('Geri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving || cards.isEmpty ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text('${cards.length} kartı kaydet'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 3) Çalışma ekranı (kart çevirme + Leitner tekrar)
// ============================================================
class FlashcardStudyPage extends StatefulWidget {
  const FlashcardStudyPage({super.key, required this.deck, this.all = false});
  final FcDeck deck;
  final bool all;

  @override
  State<FlashcardStudyPage> createState() => _FlashcardStudyPageState();
}

class _FlashcardStudyPageState extends State<FlashcardStudyPage> {
  final List<FcCard> _queue = [];
  int _pos = 0;
  int _initial = 0;
  bool _flipped = false;
  bool _loading = true;
  bool _busy = false;
  int _known = 0;
  int _unknown = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool? all}) async {
    final cards =
        await FlashcardDb.cards(widget.deck.id, onlyDue: !(all ?? widget.all));
    cards.shuffle();
    if (!mounted) return;
    setState(() {
      _queue
        ..clear()
        ..addAll(cards);
      _initial = cards.length;
      _pos = 0;
      _known = 0;
      _unknown = 0;
      _flipped = false;
      _loading = false;
    });
  }

  Future<void> _answer(bool known) async {
    if (_busy || _pos >= _queue.length) return;
    _busy = true;
    final card = _queue[_pos];
    await FlashcardDb.review(card, known);
    if (!mounted) return;
    setState(() {
      if (known) {
        _known++;
      } else {
        _unknown++;
        _queue.add(card); // bilinmeyen kart oturum sonunda tekrar gelir
      }
      _pos++;
      _flipped = false;
    });
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _queue.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: EmptyState(
                      icon: Icons.check_circle_outline,
                      message: 'Bu destede şu an çalışılacak kart yok.',
                      actionLabel: 'Geri dön',
                      onAction: () => Navigator.pop(context),
                      compact: false,
                    ),
                  ),
                )
              : _pos >= _queue.length
                  ? _finished(context)
                  : _studyView(context, cs),
    );
  }

  Widget _studyView(BuildContext context, ColorScheme cs) {
    final card = _queue[_pos];
    final done = _known;
    final progress = _initial == 0 ? 0.0 : (done / _initial).clamp(0.0, 1.0).toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$done/$_initial'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_pos),
                  tween: Tween(begin: 0, end: _flipped ? 1 : 0),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  builder: (context, v, _) {
                    final angle = v * math.pi;
                    final showBack = v >= 0.5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: showBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _face(context, card.back, back: true),
                            )
                          : _face(context, card.front, back: false),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_flipped)
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _flipped = true),
                icon: const Icon(Icons.flip),
                label: const Text('Cevabı göster'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _answer(false),
                      icon: Icon(Icons.close, color: cs.error),
                      label: Text('Bilmiyorum', style: TextStyle(color: cs.error)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: BorderSide(color: cs.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _answer(true),
                      icon: const Icon(Icons.check),
                      label: const Text('Biliyorum'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _face(BuildContext context, String text, {required bool back}) {
    final cs = Theme.of(context).colorScheme;
    final bg = back ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fg = back ? cs.onPrimaryContainer : cs.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withAlpha(25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(back ? 'CEVAP' : 'SORU',
              style: TextStyle(
                  color: fg.withAlpha(150), letterSpacing: 2, fontWeight: FontWeight.w600)),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg),
                ),
              ),
            ),
          ),
          if (!back)
            Text('Çevirmek için dokun',
                style: TextStyle(color: fg.withAlpha(130), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _finished(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.emoji_events_outlined, size: 40, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Oturum tamamlandı!', style: tt.headlineSmall),
            const SizedBox(height: 8),
            Text('$_initial kartın hepsini bildin.',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Toplam $_unknown kez "Bilmiyorum" dedin.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load(all: true);
                  },
                  child: const Text('Tekrar çalış'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bitir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
