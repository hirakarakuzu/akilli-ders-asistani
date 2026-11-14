import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../api.dart' show ApiException;
import '../../config.dart';

/// n8n "flashcard-olustur" webhook'u. api.dart'a dokunmadan aynı hata dilini kullanır.
class FlashcardApi {
  FlashcardApi._();

  static Future<List<Map<String, String>>> generate(String text, {int count = 10}) async {
    if (text.trim().isEmpty) throw ApiException('Ders notu boş olamaz.');
    final clipped = text.length > 6000 ? text.substring(0, 6000) : text;
    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.n8nBaseUrl}/webhook/flashcard-olustur'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': clipped, 'count': count}),
          )
          .timeout(const Duration(seconds: 240));
      if (res.statusCode == 404) {
        throw ApiException(
            'Flashcard servisi bulunamadı. n8n içinde "Flashcard Olustur" akışının aktif olduğundan emin olun.');
      }
      if (res.statusCode != 200) {
        throw ApiException(
            'Sunucu isteği işleyemedi. n8n ve Ollama servislerinin çalıştığından emin olun.');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map || data['success'] != true) {
        throw ApiException((data is Map ? data['error']?.toString() : null) ??
            'Kartlar oluşturulamadı. Tekrar deneyin.');
      }
      final raw = data['cards'];
      final cards = <Map<String, String>>[];
      if (raw is List) {
        for (final c in raw) {
          if (c is! Map) continue;
          final f = (c['front'] ?? '').toString().trim();
          final b = (c['back'] ?? '').toString().trim();
          if (f.isNotEmpty && b.isNotEmpty) cards.add({'front': f, 'back': b});
        }
      }
      if (cards.length < 3) {
        throw ApiException('Yeterli kart üretilemedi. Daha uzun bir not ile tekrar deneyin.');
      }
      return cards;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Yapay zekâ yanıtı gecikti. Biraz sonra tekrar deneyin.');
    } on SocketException {
      throw ApiException('Sunucuya ulaşılamıyor. n8n servisini kontrol edin.');
    } on http.ClientException {
      throw ApiException('Sunucuya ulaşılamıyor. n8n servisini kontrol edin.');
    } on FormatException {
      throw ApiException('Sunucudan okunamayan bir yanıt geldi.');
    }
  }
}
