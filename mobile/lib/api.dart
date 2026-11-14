import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Tüm yapay zekâ istekleri n8n webhook'larına gider. Ollama'ya doğrudan erişim yoktur.
class Api {
  static String _clip(String t) => t.length > 6000 ? t.substring(0, 6000) : t;

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.n8nBaseUrl}/webhook/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 240));
      if (res.statusCode != 200) {
        throw ApiException(
            'Sunucu isteği işleyemedi. n8n ve Ollama servislerinin çalıştığından emin olun.');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw ApiException('Sunucudan beklenmeyen bir yanıt geldi.');
      }
      if (data['success'] != true) {
        throw ApiException(
            data['error']?.toString() ?? 'İşlem tamamlanamadı. Lütfen tekrar deneyin.');
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Yapay zekâ yanıtı gecikti. Biraz sonra tekrar deneyin.');
    } on SocketException {
      throw ApiException(
          'Sunucuya ulaşılamıyor. İnternet bağlantınızı ve n8n servisini kontrol edin.');
    } on http.ClientException {
      throw ApiException(
          'Sunucuya ulaşılamıyor. İnternet bağlantınızı ve n8n servisini kontrol edin.');
    } on FormatException {
      throw ApiException('Sunucudan okunamayan bir yanıt geldi.');
    }
  }

  static Future<String> chat(String message) async {
    final d = await _post('chat', {'message': message});
    return (d['reply'] ?? '').toString();
  }

  static Future<String> summarize(String text) async {
    if (text.trim().isEmpty) throw ApiException('Ders notu boş olamaz.');
    final d = await _post('ozet', {'text': _clip(text)});
    return (d['summary'] ?? '').toString();
  }

  static Future<List<Question>> generateTest(String text) async {
    if (text.trim().isEmpty) throw ApiException('Ders notu boş olamaz.');
    final d = await _post('test-olustur', {'text': _clip(text)});
    final raw = d['questions'];
    final list = <Question>[];
    if (raw is List) {
      for (final q in raw) {
        final parsed = Question.tryParse(q);
        if (parsed != null) list.add(parsed);
      }
    }
    if (list.length < 5) {
      throw ApiException('Yeterli sayıda geçerli soru üretilemedi. Tekrar deneyin.');
    }
    return list;
  }

  static Future<Map<String, dynamic>> evaluate(List<Question> questions) {
    return _post('performans', {
      'questions': questions.map((q) => q.toApiJson()).toList(),
    });
  }
}
