import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema seçimini yönetir ve cihaza kaydeder.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    _mode = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> setMode(ThemeMode m) async {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, m.name);
  }
}

/// Uygulama genelinde tek örnek.
final themeController = ThemeController();
