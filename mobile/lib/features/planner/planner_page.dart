import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth.dart';
import '../../core/utils/activity.dart';
import '../../db.dart';
import '../progress/progress_repo.dart';

const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _dayLong = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const _taskTypes = [
  'Konu tekrarı yap',
  'Notlarından test çöz',
  'Flashcard tekrarı yap',
  'Yanlış yaptığın konuları çalış',
  'Kısa özet çıkar',
];

class PlanItem {
  PlanItem(this.day, this.subject, this.minutes, this.task, {this.done = false});
  final int day; // 0 = Pazartesi
  final String subject;
  final int minutes;
  final String task;
  bool done;

  Map<String, dynamic> toJson() =>
      {'day': day, 'subject': subject, 'minutes': minutes, 'task': task, 'done': done};
  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
        (j['day'] as num).toInt(),
        j['subject'].toString(),
        (j['minutes'] as num).toInt(),
        j['task'].toString(),
        done: j['done'] == true,
      );
}

/// Plan telefonda saklanır; her yeni haftada işaretler sıfırlanır.
class PlanStore {
  static String get _key => 'study_plan_${Session.userId ?? 0}';

  static String weekKey(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  static Future<List<PlanItem>?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final items = (j['items'] as List)
          .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (j['week'] != weekKey(DateTime.now())) {
        for (final i in items) {
          i.done = false;
        }
        await save(items);
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(List<PlanItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode({
      'week': weekKey(DateTime.now()),
      'items': items.map((e) => e.toJson()).toList(),
    }));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  /// Zayıf derslere daha fazla oturum düşecek şekilde haftalık plan üretir.
  static List<PlanItem> generate({
    required List<String> subjects,
    required Set<int> days,
    required int dailyMinutes,
    required int sessionMinutes,
    required Map<String, int> averages,
  }) {
    final perDay = (dailyMinutes / sessionMinutes).floor().clamp(1, 8).toInt();
    final total = perDay * days.length;
    // Ağırlık: başarı düştükçe artar. Test çözülmemiş ders orta ağırlık alır.
    final weights = {
      for (final s in subjects) s: 1 + (100 - (averages[s] ?? 50)) / 50,
    };
    final sum = weights.values.fold<double>(0, (a, b) => a + b);
    final quota = <String, int>{
      for (final s in subjects) s: (total * weights[s]! / sum).floor(),
    };
    var assigned = quota.values.fold<int>(0, (a, b) => a + b);
    final byWeight = [...subjects]..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    var k = 0;
    while (assigned < total) {
      final s = byWeight[k % byWeight.length];
      quota[s] = quota[s]! + 1;
      assigned++;
      k++;
    }
    // Aynı dersin art arda gelmemesi için sırayla dağıt.
    final pool = <String>[];
    while (pool.length < total) {
      for (final s in byWeight) {
        if (quota[s]! > 0) {
          pool.add(s);
          quota[s] = quota[s]! - 1;
        }
      }
    }
    final sortedDays = days.toList()..sort();
    final items = <PlanItem>[];
    var idx = 0;
    for (final d in sortedDays) {
      for (var n = 0; n < perDay; n++) {
        final s = pool[idx];
        final weak = (averages[s] ?? 100) < 60;
        final task = weak && n == 0 ? _taskTypes[3] : _taskTypes[(idx + d) % _taskTypes.length];
        items.add(PlanItem(d, s, sessionMinutes, task));
        idx++;
      }
    }
    return items;
  }
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  List<PlanItem>? _plan;
  bool _loading = true;
  int _day = DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PlanStore.load();
    if (!mounted) return;
    setState(() {
      _plan = p;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<List<PlanItem>>(
      MaterialPageRoute(builder: (_) => const PlanSetupPage()),
    );
    if (created != null) {
      await PlanStore.save(created);
      if (mounted) setState(() => _plan = created);
    }
  }

  Future<void> _toggle(PlanItem i, bool v) async {
    if (i.done == v) return;
    setState(() => i.done = v);
    await PlanStore.save(_plan!);
    await ActivityLog.add(Session.userId, (v ? 1 : -1) * i.minutes * 60, 'plan');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışma Planı'),
        actions: [
          if (plan != null)
            IconButton(
              tooltip: 'Yeni plan oluştur',
              icon: const Icon(Icons.refresh),
              onPressed: _create,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null || plan.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.event_note_outlined, size: 40, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 16),
                      Text('Haftalık planını oluştur', style: tt.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Derslerini ve ne kadar vaktin olduğunu seç. Test sonuçlarına göre zayıf olduğun '
                        'derslere daha fazla zaman ayırırım.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Plan oluştur'),
                      ),
                    ]),
                  ),
                )
              : _planView(context, plan),
    );
  }

  Widget _planView(BuildContext context, List<PlanItem> plan) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final done = plan.where((p) => p.done).length;
    final today = plan.where((p) => p.day == _day).toList();
    final todayIdx = DateTime.now().weekday - 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bu hafta: $done/${plan.length} oturum tamamlandı',
                style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: plan.isEmpty ? 0 : done / plan.length,
                minHeight: 8,
                backgroundColor: cs.surface,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 64,
          child: Row(children: [
            for (var d = 0; d < 7; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayChip(
                    label: _dayNames[d],
                    count: plan.where((p) => p.day == d).length,
                    doneCount: plan.where((p) => p.day == d && p.done).length,
                    selected: d == _day,
                    isToday: d == todayIdx,
                    onTap: () => setState(() => _day = d),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('${_dayLong[_day]}${_day == todayIdx ? ' (bugün)' : ''}', style: tt.titleMedium),
        const SizedBox(height: 8),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Bu gün dinlenme günü 🎉',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        for (final i in today)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: CheckboxListTile(
              value: i.done,
              onChanged: (v) => _toggle(i, v ?? false),
              title: Text(i.subject,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: i.done ? TextDecoration.lineThrough : null)),
              subtitle: Text('${i.task} · ${i.minutes} dk'),
              secondary: CircleAvatar(
                backgroundColor: i.done ? cs.primary : cs.secondaryContainer,
                child: Icon(i.done ? Icons.check : Icons.menu_book_outlined,
                    color: i.done ? cs.onPrimary : cs.onSecondaryContainer),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.count,
    required this.doneCount,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });
  final String label;
  final int count;
  final int doneCount;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final complete = count > 0 && doneCount == count;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? cs.onPrimary : cs.onSurface)),
          const SizedBox(height: 4),
          complete
              ? Icon(Icons.check_circle, size: 16, color: selected ? cs.onPrimary : cs.primary)
              : Text(count == 0 ? '–' : '$doneCount/$count',
                  style: TextStyle(fontSize: 12, color: selected ? cs.onPrimary : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------
// Plan kurulumu
// ------------------------------------------------------------
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key});

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  List<String> _subjects = [];
  Map<String, int> _avg = {};
  final Set<String> _picked = {};
  final Set<int> _days = {0, 1, 2, 3, 4};
  double _daily = 90;
  int _session = 30;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Session.userId ?? 0;
    final rows = await Repo.subjects(uid);
    final avg = await ProgressRepo.subjectAverages(uid);
    if (!mounted) return;
    setState(() {
      _subjects = rows.map((r) => (r['name'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
      _avg = avg;
      _picked.addAll(_subjects.where((s) => s != 'Genel'));
      if (_picked.isEmpty) _picked.addAll(_subjects);
      _loading = false;
    });
  }

  void _generate() {
    final items = PlanStore.generate(
      subjects: _subjects.where(_picked.contains).toList(),
      days: _days,
      dailyMinutes: _daily.round(),
      sessionMinutes: _session,
      averages: _avg,
    );
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ok = _picked.isNotEmpty && _days.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan ayarları')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Dersler', style: tt.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _subjects)
                    FilterChip(
                      label: Text(_avg[s] != null ? '$s · %${_avg[s]}' : s),
                      selected: _picked.contains(s),
                      onSelected: (v) => setState(() => v ? _picked.add(s) : _picked.remove(s)),
                    ),
                ]),
                const SizedBox(height: 20),
                Text('Çalışma günleri', style: tt.titleMedium),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var d = 0; d < 7; d++)
                    FilterChip(
                      label: Text(_dayNames[d]),
                      selected: _days.contains(d),
                      onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                    ),
                ]),
                const SizedBox(height: 20),
                Text('Günlük süre: ${_daily.round()} dakika', style: tt.titleMedium),
                Slider(
                  value: _daily,
                  min: 30,
                  max: 240,
                  divisions: 14,
                  label: '${_daily.round()} dk',
                  onChanged: (v) => setState(() => _daily = v),
                ),
                Text('Oturum uzunluğu', style: tt.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 25, label: Text('25 dk')),
                    ButtonSegment(value: 30, label: Text('30 dk')),
                    ButtonSegment(value: 45, label: Text('45 dk')),
                    ButtonSegment(value: 60, label: Text('60 dk')),
                  ],
                  selected: {_session},
                  onSelectionChanged: (s) => setState(() => _session = s.first),
                ),
                const SizedBox(height: 16),
                Text(
                  'Günde ${(_daily / _session).floor().clamp(1, 8)} oturum, haftada '
                  '${(_daily / _session).floor().clamp(1, 8) * _days.length} oturum planlanacak.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: ok ? _generate : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Planı oluştur'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ),
    );
  }
}
