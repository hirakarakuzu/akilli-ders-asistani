import 'package:shared_preferences/shared_preferences.dart';
import '../../db.dart';

class ActivitySummary {
  ActivitySummary({
    required this.todayMinutes,
    required this.goalMinutes,
    required this.streak,
    required this.weekMinutes,
    required this.totalMinutes,
  });

  final int todayMinutes;
  final int goalMinutes;
  final int streak;

  /// Bu haftanın Pzt..Paz dakikaları.
  final List<int> weekMinutes;
  final int totalMinutes;
}

/// Çalışma süresi kaydı: test, flashcard, sohbet, not ve plan işlemleri buraya süre ekler.
/// Ana sayfadaki günlük hedef, seri ve haftalık grafik buradan hesaplanır.
class ActivityLog {
  ActivityLog._();

  static bool _ready = false;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> _ensure() async {
    if (_ready) return;
    final d = await AppDb.instance;
    await d.execute('''CREATE TABLE IF NOT EXISTS activity_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      day TEXT NOT NULL,
      seconds INTEGER NOT NULL,
      kind TEXT,
      created_at TEXT NOT NULL)''');
    await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_user_day ON activity_log(user_id, day)');
    _ready = true;
  }

  /// Süre ekler. Geri almak için negatif değer verilebilir. Hata olursa sessizce geçer.
  static Future<void> add(int? uid, int seconds, String kind) async {
    if (uid == null || seconds == 0) return;
    try {
      await _ensure();
      final d = await AppDb.instance;
      final now = DateTime.now();
      await d.insert('activity_log', {
        'user_id': uid,
        'day': dayKey(now),
        'seconds': seconds,
        'kind': kind,
        'created_at': now.toIso8601String(),
      });
    } catch (_) {}
  }

  static String _goalKey(int uid) => 'daily_goal_minutes_$uid';

  static Future<int> goal(int uid) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_goalKey(uid)) ?? 60;
  }

  static Future<void> setGoal(int uid, int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_goalKey(uid), minutes);
  }

  static Future<ActivitySummary> summary(int uid) async {
    await _ensure();
    final d = await AppDb.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rows = await d.rawQuery(
        'SELECT day, SUM(seconds) AS s FROM activity_log WHERE user_id = ? GROUP BY day',
        [uid]);
    final byDay = <String, int>{
      for (final r in rows) (r['day'] as String): ((r['s'] as num?)?.toInt() ?? 0),
    };
    int minutesOf(DateTime day) {
      final s = byDay[dayKey(day)] ?? 0;
      return s <= 0 ? 0 : (s / 60).round();
    }

    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = [for (var i = 0; i < 7; i++) minutesOf(monday.add(Duration(days: i)))];

    // Seri: bugün henüz çalışılmadıysa dünden geriye sayılır, böylece gün bitmeden seri bozulmaz.
    var streak = 0;
    var cursor = minutesOf(today) > 0 ? today : today.subtract(const Duration(days: 1));
    while (minutesOf(cursor) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final total = byDay.values.fold<int>(0, (a, b) => a + (b > 0 ? b : 0));

    return ActivitySummary(
      todayMinutes: minutesOf(today),
      goalMinutes: await goal(uid),
      streak: streak,
      weekMinutes: week,
      totalMinutes: (total / 60).round(),
    );
  }
}
