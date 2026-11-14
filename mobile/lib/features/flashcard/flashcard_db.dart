import 'package:sqflite/sqflite.dart';
import '../../auth.dart';
import '../../core/utils/activity.dart';
import '../../db.dart';

/// Flashcard verileri. Mevcut db.dart'a dokunmaz; tablolar ilk kullanımda
/// "CREATE TABLE IF NOT EXISTS" ile eklenir, eski veriler etkilenmez.
class FcDeck {
  FcDeck({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.total,
    required this.learned,
    required this.due,
  });

  final int id;
  final String title;
  final int createdAt;
  final int total;
  final int learned;
  final int due;

  double get progress => total == 0 ? 0 : learned / total;
}

class FcCard {
  FcCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.box,
    required this.dueAt,
  });

  final int id;
  final int deckId;
  final String front;
  final String back;
  int box;
  int dueAt;

  factory FcCard.fromRow(Map<String, Object?> r) => FcCard(
        id: (r['id'] as num).toInt(),
        deckId: (r['deck_id'] as num).toInt(),
        front: (r['front'] as String?) ?? '',
        back: (r['back'] as String?) ?? '',
        box: (r['box'] as num?)?.toInt() ?? 0,
        dueAt: (r['due_at'] as num?)?.toInt() ?? 0,
      );
}

class FlashcardDb {
  FlashcardDb._();

  /// Leitner kutuları: kutu numarasına göre kaç gün sonra tekrar sorulacağı.
  static const intervalDays = [0, 1, 2, 4, 7, 15];

  /// Bu kutuya ulaşan kart "öğrenildi" sayılır.
  static const learnedBox = 3;

  static bool _ready = false;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static Future<Database> _db() async {
    final d = await AppDb.instance;
    if (!_ready) {
      await d.execute('''CREATE TABLE IF NOT EXISTS fc_decks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL)''');
      await d.execute('''CREATE TABLE IF NOT EXISTS fc_cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id INTEGER NOT NULL REFERENCES fc_decks(id) ON DELETE CASCADE,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        box INTEGER NOT NULL DEFAULT 0,
        due_at INTEGER NOT NULL DEFAULT 0,
        known_count INTEGER NOT NULL DEFAULT 0,
        unknown_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed INTEGER)''');
      await d.execute(
          'CREATE INDEX IF NOT EXISTS idx_fc_cards_deck ON fc_cards(deck_id)');
      _ready = true;
    }
    return d;
  }

  static Future<List<FcDeck>> decks(int uid) async {
    final d = await _db();
    final rows = await d.rawQuery(
      'SELECT d.id, d.title, d.created_at, '
      '(SELECT COUNT(*) FROM fc_cards c WHERE c.deck_id = d.id) AS total, '
      '(SELECT COUNT(*) FROM fc_cards c WHERE c.deck_id = d.id AND c.box >= ?) AS learned, '
      '(SELECT COUNT(*) FROM fc_cards c WHERE c.deck_id = d.id AND c.due_at <= ?) AS due '
      'FROM fc_decks d WHERE d.user_id = ? ORDER BY d.id DESC',
      [learnedBox, _now(), uid],
    );
    return rows
        .map((r) => FcDeck(
              id: (r['id'] as num).toInt(),
              title: (r['title'] as String?) ?? 'Deste',
              createdAt: (r['created_at'] as num?)?.toInt() ?? 0,
              total: (r['total'] as num?)?.toInt() ?? 0,
              learned: (r['learned'] as num?)?.toInt() ?? 0,
              due: (r['due'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  /// cards: [{'front': ..., 'back': ...}]
  static Future<int> createDeck(
      int uid, String title, List<Map<String, String>> cards) async {
    final d = await _db();
    return d.transaction((txn) async {
      final id = await txn.insert('fc_decks', {
        'user_id': uid,
        'title': title,
        'created_at': _now(),
      });
      for (final c in cards) {
        await txn.insert('fc_cards', {
          'deck_id': id,
          'front': c['front'] ?? '',
          'back': c['back'] ?? '',
          'box': 0,
          'due_at': 0,
        });
      }
      return id;
    });
  }

  static Future<List<FcCard>> cards(int deckId, {bool onlyDue = true}) async {
    final d = await _db();
    final rows = await d.query(
      'fc_cards',
      where: onlyDue ? 'deck_id = ? AND due_at <= ?' : 'deck_id = ?',
      whereArgs: onlyDue ? [deckId, _now()] : [deckId],
      orderBy: 'box ASC, id ASC',
    );
    return rows.map(FcCard.fromRow).toList();
  }

  /// "Biliyorum" → bir üst kutu, "Bilmiyorum" → ilk kutuya döner.
  static Future<void> review(FcCard c, bool known) async {
    final d = await _db();
    final box = known ? (c.box + 1).clamp(0, intervalDays.length - 1).toInt() : 0;
    final due = known
        ? DateTime.now().add(Duration(days: intervalDays[box])).millisecondsSinceEpoch
        : _now();
    c.box = box;
    c.dueAt = due;
    await d.rawUpdate(
      'UPDATE fc_cards SET box = ?, due_at = ?, last_reviewed = ?, '
      '${known ? 'known_count' : 'unknown_count'} = '
      '${known ? 'known_count' : 'unknown_count'} + 1 WHERE id = ?',
      [box, due, _now(), c.id],
    );
    await ActivityLog.add(Session.userId, 30, 'flashcard');
  }

  static Future<void> resetDeck(int deckId) async {
    final d = await _db();
    await d.update('fc_cards', {'box': 0, 'due_at': 0},
        where: 'deck_id = ?', whereArgs: [deckId]);
  }

  static Future<void> deleteDeck(int uid, int deckId) async {
    final d = await _db();
    await d.delete('fc_cards', where: 'deck_id = ?', whereArgs: [deckId]);
    await d.delete('fc_decks',
        where: 'id = ? AND user_id = ?', whereArgs: [deckId, uid]);
  }
}
