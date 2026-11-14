import 'package:flutter/material.dart';
import '../auth.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_controller.dart';
import '../core/utils/text_utils.dart';
import '../core/widgets/brand.dart';
import '../core/widgets/dashboard_widgets.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/profile_menu.dart';
import '../core/widgets/stat_card.dart';
import '../db.dart';
import '../widgets.dart' hide EmptyState;
import 'chat_screen.dart';
import 'flows.dart';
import 'quiz_screen.dart';
import '../core/utils/activity.dart';
import '../core/utils/default_subjects.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) goTo;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.goTo, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List<DbRow> subjects = [];
  List<DbRow> chats = [];
  List<DbRow> tests = [];
  Map<String, int> stats = {'results': 0, 'avg': 0, 'notes': 0, 'chats': 0};

  // Çalışma kaydından (ActivityLog) doldurulur.
  int todayMinutes = 0;
  int totalMinutes = 0;
  List<int> weekMinutes = const [0, 0, 0, 0, 0, 0, 0];
  int goalMinutes = 60;
  int streak = 0;
  List<double> weekly = const [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId!;
    await ensureDefaultSubjects(uid);
    final s = await Repo.subjects(uid);
    final c = await Repo.conversations(uid, limit: 3);
    final t = await Repo.tests(uid, limit: 3);
    final st = await Repo.stats(uid);
    final act = await ActivityLog.summary(uid);
    if (!mounted) return;
    setState(() {
      todayMinutes = act.todayMinutes;
      goalMinutes = act.goalMinutes;
      streak = act.streak;
      totalMinutes = act.totalMinutes;
      weekMinutes = act.weekMinutes;
      weekly = [
        for (final m in act.weekMinutes)
          act.goalMinutes == 0 ? 0.0 : (m * 100 / act.goalMinutes).clamp(0, 100).toDouble()
      ];
      subjects = s;
      chats = c;
      tests = t;
      stats = st;
      loading = false;
    });
  }

  // Çözülen testlerden türetilen basit XP / seviye.
  int get xp => (stats['results'] ?? 0) * 10 + totalMinutes;

  Future<void> _editGoal() async {
    const options = [15, 30, 45, 60, 90, 120, 180];
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Günlük hedefin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          for (final m in options)
            ListTile(
              leading: Icon(m == goalMinutes ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text('$m dakika'),
              onTap: () => Navigator.pop(c, m),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    await ActivityLog.setGoal(Session.userId!, picked);
    _load();
  }
  int get level => xp ~/ 100 + 1;

  String get suggestion {
    final notes = stats['notes'] ?? 0;
    final results = stats['results'] ?? 0;
    final avg = stats['avg'] ?? 0;
    if (notes == 0) return 'Bugün ilk notunu ekle, sonra ondan test oluşturabilirsin.';
    if (results == 0) return 'Notlarından bir test oluştur ve kendini dene.';
    if (avg < 60) return 'Başarı oranın %$avg. Yanlış yaptığın konuları asistana sorarak tekrar et.';
    return 'Başarı oranın %$avg, harika gidiyorsun. Yeni bir test çözerek seriyi sürdür.';
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final goal = goalMinutes == 0 ? 0.0 : (todayMinutes / goalMinutes).clamp(0.0, 1.0);
    final name = Session.userName?.isNotEmpty == true ? toTitleCaseTr(Session.userName!) : 'Öğrenci';

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(size: 34),
        actions: [
          ProfileMenu(themeController: themeController, onLogout: widget.onLogout),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                // Karşılama
                HeroCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SoftBadge(
                      text: streak > 0 ? '$streak gün seri 🔥' : 'Bugün yeni bir başlangıç',
                      color: AppColors.coral,
                    ),
                    const SizedBox(height: 14),
                    Text('Merhaba, $name 👋', style: tt.headlineSmall),
                    const SizedBox(height: 6),
                    Text('Bugün ne öğrenmek istersin?',
                        style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: GradientButton(
                          icon: Icons.auto_awesome,
                          onPressed: () async {
                            await startNewChat(context);
                            _load();
                          },
                          child: const Text('Asistana sor'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => widget.goTo(4),
                        style: OutlinedButton.styleFrom(backgroundColor: cs.surfaceContainerLow),
                        child: const Text('Araçlar'),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // İstatistikler
                Row(children: [
                  Expanded(child: StatCard(icon: Icons.emoji_events_outlined, value: '%${stats['avg']}', label: 'Başarı', color: AppColors.amber)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(icon: Icons.quiz_outlined, value: '${stats['results']}', label: 'Test', color: AppColors.sky)),
                  const SizedBox(width: 10),
                  Expanded(child: StatCard(icon: Icons.note_alt_outlined, value: '${stats['notes']}', label: 'Not', color: AppColors.lavender)),
                ]),

                // Günlük hedef
                _section('Günlük hedef'),
                AppCard(
                  onTap: _editGoal,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('$todayMinutes / $goalMinutes dk', style: tt.titleMedium),
                      Text('%${(goal * 100).round()}', style: tt.titleMedium?.copyWith(color: cs.primary)),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                          value: goal, minHeight: 10, backgroundColor: cs.surfaceContainerHigh, color: cs.secondary),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      InfoPill(icon: Icons.local_fire_department_outlined, text: '$streak gün seri'),
                      const SizedBox(width: 8),
                      InfoPill(icon: Icons.bolt, text: '$xp XP · Sv.$level'),
                      const Spacer(),
                      Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      todayMinutes >= goalMinutes
                          ? 'Bugünkü hedefini tamamladın!'
                          : 'Test, flashcard, sohbet ve plan oturumların süreye eklenir.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ]),
                ),

                // Haftalık grafik
                _section('Bu haftaki çalışman'),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Toplam ${weekMinutes.fold<int>(0, (a, b) => a + b)} dk · çubuklar günlük hedefe göre',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    WeeklyBars(values: weekly),
                  ]),
                ),

                // Günün önerisi
                _section('Günün önerisi'),
                AppCard(
                  child: Row(children: [
                    Icon(Icons.tips_and_updates_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(suggestion)),
                  ]),
                ),

                // Hızlı işlemler
                _section('Hızlı işlemler'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await startNewChat(context);
                      _load();
                    },
                    icon: const Icon(Icons.smart_toy_outlined),
                    label: const Text('Asistana sor'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => widget.goTo(2),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Not ekle'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => widget.goTo(3),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Testlerim'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => widget.goTo(4),
                    icon: const Icon(Icons.apps),
                    label: const Text('Araçlar'),
                  ),
                ]),

                // Dersler
                _section('Derslerim'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in subjects)
                    Chip(
                        avatar: CircleAvatar(radius: 6, backgroundColor: AppColors.colorFor(s['name'] as String)),
                        label: Text(s['name'] as String)),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Ders ekle'),
                    onPressed: () async {
                      await addSubjectDialog(context);
                      _load();
                    },
                  ),
                ]),

                // Son sohbetler
                _section('Son sohbetler'),
                if (chats.isEmpty)
                  const EmptyState(icon: Icons.chat_bubble_outline, message: 'Henüz sohbet yok. "Asistana sor" ile başla.')
                else
                  for (final c in chats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(conversationId: c['id'] as int, title: c['title'] as String)));
                          _load();
                        },
                        child: Row(children: [
                          const Icon(Icons.chat_bubble_outline),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c['title'] as String,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${c['subject_name'] ?? 'Genel'} • ${fmtDate(c['created_at'] as String)}',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                        ]),
                      ),
                    ),

                // Son testler
                _section('Son testler'),
                if (tests.isEmpty)
                  const EmptyState(icon: Icons.quiz_outlined, message: 'Henüz test yok. Bir nottan test oluştur.')
                else
                  for (final t in tests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () async {
                          final qs = await Repo.testQuestions(t['id'] as int);
                          if (!context.mounted) return;
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => QuizScreen(testId: t['id'] as int, title: t['title'] as String, questions: qs)));
                          _load();
                        },
                        child: Row(children: [
                          const Icon(Icons.quiz_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t['title'] as String,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(t['last_pct'] == null ? 'Henüz çözülmedi' : 'Son sonuç: %${t['last_pct']}',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
              ]),
            ),
    );
  }
}
