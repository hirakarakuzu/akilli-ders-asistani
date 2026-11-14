import 'package:flutter/material.dart';
import 'auth.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  await themeController.load();
  runApp(const DersApp());
}

class DersApp extends StatefulWidget {
  const DersApp({super.key});
  @override
  State<DersApp> createState() => _DersAppState();
}

class _DersAppState extends State<DersApp> {
  bool loggedIn = Session.userId != null;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Bilge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeController.mode,
        home: loggedIn
            ? Shell(
                key: ValueKey(Session.userId),
                onLogout: () async {
                  await Session.clear();
                  setState(() => loggedIn = false);
                })
            : LoginScreen(onLoggedIn: () => setState(() => loggedIn = true)),
      ),
    );
  }
}

