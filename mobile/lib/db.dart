import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

typedef DbRow = Map<String, Object?>;

class AppDb {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'ders_asistani.db');
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT,
          email TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE subjects(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          name TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE conversations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
          title TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
          role TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE study_notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          subject_id INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
          title TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE tests(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          note_id INTEGER REFERENCES study_notes(id) ON DELETE SET NULL,
          title TEXT NOT NULL, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE questions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          test_id INTEGER NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
          question TEXT NOT NULL, topic TEXT, options_json TEXT NOT NULL,
          correct_answer TEXT NOT NULL, explanation TEXT)''');
        await d.execute('''CREATE TABLE test_results(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          test_id INTEGER NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
          total INTEGER, correct INTEGER, percentage INTEGER,
          weak_topics TEXT, created_at TEXT NOT NULL)''');
        await d.execute('''CREATE TABLE study_recommendations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          result_id INTEGER NOT NULL REFERENCES test_results(id) ON DELETE CASCADE,
          content TEXT NOT NULL, created_at TEXT NOT NULL)''');
      },
    );
    return _db!;
  }
}

/// Tüm sorgular user_id ile filtrelenir: kullanıcılar birbirinin verisini göremez.
class Repo {
  static String _now() => DateTime.now().toIso8601String();

  // ---- Kullanıcı ----
  static Future<DbRow?> userByEmail(String email) async {
    final d = await AppDb.instance;
    final r = await d.query('users',
        where: 'email = ?', whereArgs: [email.toLowerCase()], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  static Future<int> createUser(String name, String email, String hash) async {
    final d = await AppDb.instance;
    final id = await d.insert('users', {
      'name': name,
      'email': email.toLowerCase(),
      'password_hash': hash,
      'created_at': _now(),
    });
    await d.insert(
        'subjects', {'user_id': id, 'name': 'Genel', 'created_at': _now()});
    return id;
  }

  // ---- Dersler ----
  static Future<List<DbRow>> subjects(int uid) async {
    final d = await AppDb.instance;
    return d.query('subjects', where: 'user_id = ?', whereArgs: [uid], orderBy: 'id');
  }

  static Future<int> addSubject(int uid, String name) async {
    final d = await AppDb.instance;
    return d.insert('subjects', {'user_id': uid, 'name': name, 'created_at': _now()});
  }

  // ---- Sohbetler ----
  static Future<List<DbRow>> conversations(int uid, {int? subjectId, int? limit}) async {
    final d = await AppDb.instance;
    final args = <Object?>[uid];
    var where = 'c.user_id = ?';
    if (subjectId != null) {
      where += ' AND c.subject_id = ?';
      args.add(subjectId);
    }
    final lim = limit != null ? 'LIMIT $limit' : '';
    return d.rawQuery(
        'SELECT c.*, s.name AS subject_name FROM conversations c '
        'LEFT JOIN subjects s ON s.id = c.subject_id '
        'WHERE $where ORDER BY c.id DESC $lim',
        args);
  }

  static Future<int> createConversation(int uid, int? subjectId, String title) async {
    final d = await AppDb.instance;
    return d.insert('conversations', {
      'user_id': uid,
      'subject_id': subjectId,
      'title': title,
      'created_at': _now(),
    });
  }

  static Future<void> renameConversation(int id, String title) async {
    final d = await AppDb.instance;
    await d.update('conversations', {'title': title}, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteConversation(int uid, int id) async {
    final d = await AppDb.instance;
    await d.delete('conversations', where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  static Future<List<DbRow>> messages(int conversationId) async {
    final d = await AppDb.instance;
    return d.query('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'id');
  }

  static Future<void> addMessage(int conversationId, String role, String content) async {
    final d = await AppDb.instance;
    await d.insert('messages', {
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': _now(),
    });
  }

  // ---- Notlar ----
  static Future<List<DbRow>> notes(int uid) async {
    final d = await AppDb.instance;
    return d.rawQuery(
        'SELECT n.*, s.name AS subject_name FROM study_notes n '
        'LEFT JOIN subjects s ON s.id = n.subject_id '
        'WHERE n.user_id = ? ORDER BY n.id DESC',
        [uid]);
  }

  static Future<int> addNote(int uid, int? subjectId, String title, String content) async {
    final d = await AppDb.instance;
    return d.insert('study_notes', {
      'user_id': uid,
      'subject_id': subjectId,
      'title': title,
      'content': content,
      'created_at': _now(),
    });
  }

  static Future<void> deleteNote(int uid, int id) async {
    final d = await AppDb.instance;
    await d.delete('study_notes', where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  // ---- Testler ----
  static Future<List<DbRow>> tests(int uid, {int? limit}) async {
    final d = await AppDb.instance;
    final lim = limit != null ? 'LIMIT $limit' : '';
    return d.rawQuery(
        'SELECT t.*, (SELECT percentage FROM test_results r WHERE r.test_id = t.id '
        'ORDER BY r.id DESC LIMIT 1) AS last_pct FROM tests t '
        'WHERE t.user_id = ? ORDER BY t.id DESC $lim',
        [uid]);
  }

  static Future<int> addTest(int uid, int? noteId, String title, List<Question> qs) async {
    final d = await AppDb.instance;
    final id = await d.insert('tests', {
      'user_id': uid,
      'note_id': noteId,
      'title': title,
      'created_at': _now(),
    });
    final batch = d.batch();
    for (final q in qs) {
      batch.insert('questions', {
        'test_id': id,
        'question': q.question,
        'topic': q.topic,
        'options_json': jsonEncode(q.options),
        'correct_answer': q.correct,
        'explanation': q.explanation,
      });
    }
    await batch.commit(noResult: true);
    return id;
  }

  static Future<List<Question>> testQuestions(int testId) async {
    final d = await AppDb.instance;
    final rows = await d.query('questions',
        where: 'test_id = ?', whereArgs: [testId], orderBy: 'id');
    return rows
        .map((r) => Question(
              question: r['question'] as String,
              topic: (r['topic'] as String?) ?? 'Genel',
              options: (jsonDecode(r['options_json'] as String) as List)
                  .map((e) => e.toString())
                  .toList(),
              correct: r['correct_answer'] as String,
              explanation: (r['explanation'] as String?) ?? '',
            ))
        .toList();
  }

  static Future<void> deleteTest(int uid, int id) async {
    final d = await AppDb.instance;
    await d.delete('tests', where: 'id = ? AND user_id = ?', whereArgs: [id, uid]);
  }

  // ---- Sonuçlar ----
  static Future<void> addResult(int uid, int testId, int total, int correct, int pct,
      List<String> weakTopics, String recommendations) async {
    final d = await AppDb.instance;
    final rid = await d.insert('test_results', {
      'user_id': uid,
      'test_id': testId,
      'total': total,
      'correct': correct,
      'percentage': pct,
      'weak_topics': weakTopics.join(', '),
      'created_at': _now(),
    });
    await d.insert('study_recommendations', {
      'user_id': uid,
      'result_id': rid,
      'content': recommendations,
      'created_at': _now(),
    });
  }

  static Future<Map<String, int>> stats(int uid) async {
    final d = await AppDb.instance;
    final r = await d.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(AVG(percentage),0) AS avg FROM test_results WHERE user_id = ?',
        [uid]);
    final n = await d.rawQuery('SELECT COUNT(*) AS n FROM study_notes WHERE user_id = ?', [uid]);
    final c = await d.rawQuery('SELECT COUNT(*) AS n FROM conversations WHERE user_id = ?', [uid]);
    return {
      'results': (r.first['n'] as num).toInt(),
      'avg': (r.first['avg'] as num).round(),
      'notes': (n.first['n'] as num).toInt(),
      'chats': (c.first['n'] as num).toInt(),
    };
  }
}
