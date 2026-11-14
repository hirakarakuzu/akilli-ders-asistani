import 'package:flutter/material.dart';
import '../auth.dart';
import '../db.dart';
import '../widgets.dart';
import 'quiz_screen.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});
  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  List<DbRow> tests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await Repo.tests(Session.userId!);
    if (!mounted) return;
    setState(() {
      tests = t;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Testlerim')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : tests.isEmpty
              ? const EmptyState(icon: Icons.quiz_outlined, text: 'Henüz test yok.\nNotlar sekmesinden bir nottan test oluştur.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tests.length,
                  itemBuilder: (_, i) {
                    final t = tests[i];
                    return AppCard(
                      onTap: () async {
                        final qs = await Repo.testQuestions(t['id'] as int);
                        if (!context.mounted) return;
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => QuizScreen(testId: t['id'] as int, title: t['title'] as String, questions: qs)));
                        _load();
                      },
                      child: Row(children: [
                        const Icon(Icons.quiz_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                                '${fmtDate(t['created_at'] as String)} • ${t['last_pct'] == null ? 'Henüz çözülmedi' : 'Son sonuç: %${t['last_pct']}'}',
                                style: TextStyle(fontSize: 12, color: cs.outline)),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await Repo.deleteTest(Session.userId!, t['id'] as int);
                            _load();
                          },
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
