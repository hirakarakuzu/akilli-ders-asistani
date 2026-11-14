import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// Sağ üstteki çıkış ikonunun yerine geçer: tema seçimi + çıkış.
class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key, required this.themeController, required this.onLogout});
  final ThemeController themeController;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Profil',
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.person_outline, size: 20, color: cs.onPrimaryContainer),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        switch (v) {
          case 'light':
            themeController.setMode(ThemeMode.light);
          case 'dark':
            themeController.setMode(ThemeMode.dark);
          case 'system':
            themeController.setMode(ThemeMode.system);
          case 'logout':
            onLogout();
        }
      },
      itemBuilder: (_) => [
        _item('light', Icons.light_mode_outlined, 'Açık tema', themeController.mode == ThemeMode.light),
        _item('dark', Icons.dark_mode_outlined, 'Koyu tema', themeController.mode == ThemeMode.dark),
        _item('system', Icons.brightness_auto_outlined, 'Sistem teması', themeController.mode == ThemeMode.system),
        const PopupMenuDivider(),
        _item('logout', Icons.logout, 'Çıkış yap', false),
      ],
    );
  }

  PopupMenuItem<String> _item(String v, IconData i, String t, bool selected) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(i, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(t)),
          if (selected) const Icon(Icons.check, size: 18),
        ]),
      );
}
