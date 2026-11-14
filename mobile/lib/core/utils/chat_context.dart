import '../../auth.dart';
import '../../db.dart';

class ChatContextInfo {
  ChatContextInfo(this.subjectId, this.subjectName, this.noteCount);
  final int? subjectId;
  final String subjectName;
  final int noteCount;

  bool get isGeneral => subjectId == null || subjectName.toLowerCase() == 'genel';

  String get subtitle {
    if (isGeneral) {
      return noteCount > 0 ? 'Genel · notların taranıyor' : 'Genel sohbet';
    }
    return noteCount > 0 ? '$subjectName · $noteCount not kullanılıyor' : '$subjectName · genel bilgiyle';
  }
}

/// Sohbete ders bilgisi, ilgili not parçaları ve önceki mesajları ekleyerek
/// yapay zekâya gidecek mesajı hazırlar. n8n tarafında değişiklik gerekmez.
class ChatContext {
  ChatContext._();

  static Future<ChatContextInfo> info(int conversationId) async {
    final d = await AppDb.instance;
    final uid = Session.userId ?? 0;
    final r = await d.rawQuery(
        'SELECT c.subject_id, s.name FROM conversations c '
        'LEFT JOIN subjects s ON s.id = c.subject_id WHERE c.id = ?',
        [conversationId]);
    final sid = r.isEmpty ? null : (r.first['subject_id'] as num?)?.toInt();
    final name = r.isEmpty ? 'Genel' : ((r.first['name'] as String?) ?? 'Genel');
    final general = sid == null || name.toLowerCase() == 'genel';
    final n = await d.rawQuery(
        general
            ? 'SELECT COUNT(*) AS n FROM study_notes WHERE user_id = ?'
            : 'SELECT COUNT(*) AS n FROM study_notes WHERE user_id = ? AND subject_id = ?',
        general ? [uid] : [uid, sid]);
    return ChatContextInfo(sid, name, (n.first['n'] as num).toInt());
  }

  static Future<String> build({
    required int conversationId,
    required String question,
    required List<DbRow> history,
    ChatContextInfo? info,
  }) async {
    final inf = info ?? await ChatContext.info(conversationId);
    final notes = await _relevantNotes(inf, question);
    final b = StringBuffer();

    if (inf.isGeneral) {
      b.writeln('Sen sabırlı ve öğretici bir üniversite eğitim asistanısın.');
    } else {
      b.writeln('Sen "${inf.subjectName}" dersinde uzman, sabırlı ve öğretici bir öğretmensin. '
          'Öğrenci bu dersle ilgili sorular soruyor.');
    }
    b.writeln('Kurallar: Türkçe yanıt ver. Açık ve adım adım anlat, gerektiğinde kısa bir örnek veya '
        'çözümlü soru ekle. Uzun cevaplarda başlık ve madde işareti kullan. Emin olmadığın bilgiyi uydurma.');

    if (notes.isNotEmpty) {
      b.writeln();
      b.writeln('ÖĞRENCİNİN DERS NOTLARINDAN İLGİLİ BÖLÜMLER (önce bunlara dayan; '
          'notlarda olmayan kısmı kendi bilginle tamamla):');
      b.writeln(notes);
    } else if (!inf.isGeneral) {
      b.writeln();
      b.writeln('Öğrencinin bu ders için kayıtlı notu yok; soruyu kendi ders bilginle eksiksiz yanıtla.');
    }

    final past = history.length > 6 ? history.sublist(history.length - 6) : history;
    if (past.isNotEmpty) {
      b.writeln();
      b.writeln('ÖNCEKİ KONUŞMA (bağlam için):');
      for (final m in past) {
        final who = m['role'] == 'user' ? 'Öğrenci' : 'Asistan';
        var t = (m['content'] as String?) ?? '';
        if (t.length > 500) t = '${t.substring(0, 500)}...';
        b.writeln('$who: $t');
      }
    }

    b.writeln();
    b.writeln('ÖĞRENCİNİN SORUSU: $question');
    return b.toString();
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  /// Sorudaki kelimelerle en çok örtüşen not parçalarını seçer (en fazla ~2500 karakter).
  static Future<String> _relevantNotes(ChatContextInfo inf, String question) async {
    if (inf.noteCount == 0) return '';
    final d = await AppDb.instance;
    final uid = Session.userId ?? 0;
    final rows = await d.rawQuery(
        inf.isGeneral
            ? 'SELECT title, content FROM study_notes WHERE user_id = ? ORDER BY id DESC LIMIT 30'
            : 'SELECT title, content FROM study_notes WHERE user_id = ? AND subject_id = ? ORDER BY id DESC LIMIT 30',
        inf.isGeneral ? [uid] : [uid, inf.subjectId]);

    final chunks = <String>[];
    for (final r in rows) {
      final title = (r['title'] as String?) ?? 'Not';
      final content = (r['content'] as String?) ?? '';
      final buf = StringBuffer();
      for (final para in content.split(RegExp(r'\n\s*\n'))) {
        if (buf.length + para.length > 700 && buf.isNotEmpty) {
          chunks.add('[$title]\n${buf.toString().trim()}');
          buf.clear();
        }
        buf.writeln(para);
      }
      if (buf.isNotEmpty) chunks.add('[$title]\n${buf.toString().trim()}');
    }

    final words = _norm(question)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2)
        .map((w) => w.length > 5 ? w.substring(0, 5) : w)
        .toSet();
    final scored = <MapEntry<String, int>>[];
    for (final c in chunks) {
      final n = _norm(c);
      var s = 0;
      for (final w in words) {
        if (n.contains(w)) s++;
      }
      scored.add(MapEntry(c, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));

    final picked = <String>[];
    var len = 0;
    for (final e in scored) {
      // Genel sohbette yalnızca gerçekten ilgili notlar eklenir.
      if (e.value == 0 && (inf.isGeneral || picked.isNotEmpty)) break;
      if (len + e.key.length > 2500 && picked.isNotEmpty) break;
      picked.add(e.key);
      len += e.key.length;
    }
    return picked.join('\n---\n');
  }
}
