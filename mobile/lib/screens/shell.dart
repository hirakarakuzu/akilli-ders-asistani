import 'package:flutter/material.dart';
import '../features/tools/tools_page.dart';
import 'chat_list_screen.dart';
import 'home_screen.dart';
import 'notes_screen.dart';
import 'tests_screen.dart';

class Shell extends StatefulWidget {
  final VoidCallback onLogout;
  const Shell({super.key, required this.onLogout});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  Widget _page() {
    switch (index) {
      case 0:
        return HomeScreen(goTo: (i) => setState(() => index = i), onLogout: widget.onLogout);
      case 1:
        return const ChatListScreen();
      case 2:
        return const NotesScreen();
      case 3:
        return const TestsScreen();
      default:
        return const ToolsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(index), child: _page()),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana sayfa'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Sohbet'),
          NavigationDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt), label: 'Notlar'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'Testler'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Araçlar'),
        ],
      ),
    );
  }
}
