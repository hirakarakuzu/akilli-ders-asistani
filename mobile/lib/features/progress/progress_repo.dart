import '../../db.dart';
import '../flashcard/flashcard_db.dart';

class SubjectScore {
  SubjectScore(this.name, this.avg, this.count);
  final String name;
  final int avg;
  final int count;
}

class TopicCount {
  TopicCount(this.topic, this.count);
  final String topic;
  final int count;
}

class ResultPoint {
  ResultPoint(this.title, this.percentage, this.date);
  final String title;
  final int percentage;
  final DateTime? date;
}

class ProgressData {
  ProgressData({
    required this.results,
    required this.avg,
    required this.best,
    required this.notes,
    required this.trend,
    required this.subjects,
    required this.weakTopics,
    required this.cardsTotal,
    required this.cardsLearned,
    required this.cardsDue,
  });

  final int results;
  final int avg;
  final int best;
  final int notes;
  final List<ResultPoint> trend; // eskiden yeniye
  final List<SubjectScore> subjects; // zayıftan güçlüye
  final List<TopicCount> weakTopics; // en sık önce
  final int cardsTotal;
  final int cardsLearned;
  final int cardsDue;
}

/// Başarı Haritası, AI Koç ve Çalışma Planı'nın ortak veri kaynağı.
class ProgressRepo {
  ProgressRepo._();

  static Future<ProgressData> load(int uid) async {
    final d = await AppDb.instance;

    final o = await d.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(AVG(percentage),0) AS avg, COALESCE(MAX(percentage),0) AS best '
        'FROM test_results WHERE user_id = ?',
        [uid]);
    final notes = await d.rawQuery(
        'SELECT COUNT(*) AS n FROM study_notes WHERE user_id = ?', [uid]);

    final trendRows = await d.rawQuery(
        'SELECT r.percentage, r.created_at, t.title FROM test_results r '
        'JOIN tests t ON t.id = r.test_id WHERE r.user_id = ? ORDER BY r.id DESC LIMIT 10',
        [uid]);
    final trend = trendRows.reversed
        .map((r) => ResultPoint(
              (r['title'] as String?) ?? 'Test',
              (r['percentage'] as num?)?.toInt() ?? 0,
              DateTime.tryParse((r['created_at'] as String?) ?? ''),
            ))
        .toList();

    final subjRows = await d.rawQuery(
        'SELECT COALESCE(s.name, \'Genel\') AS name, AVG(r.percentage) AS avg, COUNT(*) AS n '
        'FROM test_results r JOIN tests t ON t.id = r.test_id '
        'LEFT JOIN study_notes nt ON nt.id = t.note_id '
        'LEFT JOIN subjects s ON s.id = nt.subject_id '
        'WHERE r.user_id = ? GROUP BY COALESCE(s.name, \'Genel\') ORDER BY avg ASC',
        [uid]);
    final subjects = subjRows
        .map((r) => SubjectScore(
              (r['name'] as String?) ?? 'Genel',
              (r['avg'] as num?)?.round() ?? 0,
              (r['n'] as num?)?.toInt() ?? 0,
            ))
        .toList();

    final weakRows = await d.rawQuery(
        'SELECT weak_topics FROM test_results WHERE user_id = ? AND weak_topics IS NOT NULL',
        [uid]);
    final counts = <String, int>{};
    for (final r in weakRows) {
      final raw = (r['weak_topics'] as String?) ?? '';
      for (final t in raw.split(',')) {
        final k = t.trim();
        if (k.isEmpty) continue;
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final weak = counts.entries.map((e) => TopicCount(e.key, e.value)).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    var total = 0, learned = 0, due = 0;
    try {
      for (final deck in await FlashcardDb.decks(uid)) {
        total += deck.total;
        learned += deck.learned;
        due += deck.due;
      }
    } catch (_) {}

    return ProgressData(
      results: (o.first['n'] as num).toInt(),
      avg: (o.first['avg'] as num).round(),
      best: (o.first['best'] as num).toInt(),
      notes: (notes.first['n'] as num).toInt(),
      trend: trend,
      subjects: subjects,
      weakTopics: weak.take(10).toList(),
      cardsTotal: total,
      cardsLearned: learned,
      cardsDue: due,
    );
  }

  /// Ders adı → ortalama başarı (test çözülmemiş dersler listede yoktur).
  static Future<Map<String, int>> subjectAverages(int uid) async {
    final p = await load(uid);
    return {for (final s in p.subjects) s.name: s.avg};
  }
}
