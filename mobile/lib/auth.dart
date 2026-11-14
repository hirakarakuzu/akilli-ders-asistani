import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';

class Session {
  static int? userId;
  static String? userName;
  static String? email;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userId = p.getInt('user_id');
    userName = p.getString('user_name');
    email = p.getString('email');
  }

  static Future<void> save(int id, String name, String mail) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('user_id', id);
    await p.setString('user_name', name);
    await p.setString('email', mail);
    userId = id;
    userName = name;
    email = mail;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('user_id');
    await p.remove('user_name');
    await p.remove('email');
    userId = null;
    userName = null;
    email = null;
  }
}

class AuthService {
  static String _hash(String email, String pw) =>
      sha256.convert(utf8.encode('${email.toLowerCase()}:$pw:ders-asistani')).toString();

  /// Hata varsa mesaj döner, başarılıysa null.
  static Future<String?> register(String name, String email, String pw) async {
    try {
      if (await Repo.userByEmail(email) != null) {
        return 'Bu e-posta ile zaten bir hesap var.';
      }
      final id = await Repo.createUser(name, email, _hash(email, pw));
      await Session.save(id, name, email.toLowerCase());
      return null;
    } catch (_) {
      return 'Hesap oluşturulamadı. Lütfen tekrar deneyin.';
    }
  }

  static Future<String?> login(String email, String pw) async {
    try {
      final u = await Repo.userByEmail(email);
      if (u == null || u['password_hash'] != _hash(email, pw)) {
        return 'E-posta veya şifre hatalı.';
      }
      await Session.save(u['id'] as int, (u['name'] as String?) ?? '', email.toLowerCase());
      return null;
    } catch (_) {
      return 'Giriş yapılamadı. Lütfen tekrar deneyin.';
    }
  }
}
