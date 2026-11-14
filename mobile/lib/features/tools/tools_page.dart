import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../coach/coach_page.dart';
import '../exam/exam_page.dart';
import '../flashcard/flashcard_page.dart';
import '../pdf_chat/pdf_chat_page.dart';
import '../planner/planner_page.dart';
import '../progress/progress_page.dart';

class ToolItem {
  const ToolItem(this.icon, this.title, this.subtitle, {this.builder});
  final IconData icon;
  final String title;
  final String subtitle;

  /// Modülü yazdıkça buraya sayfanı bağla: (_) => const FlashcardPage()
  final WidgetBuilder? builder;
}

Widget _flashcardPage(BuildContext _) => const FlashcardPage();
Widget _plannerPage(BuildContext _) => const PlannerPage();
Widget _examPage(BuildContext _) => const ExamSetupPage();
Widget _progressPage(BuildContext _) => const ProgressPage();
Widget _pdfPage(BuildContext _) => const PdfChatPage();
Widget _coachPage(BuildContext _) => const CoachPage();

const toolItems = <ToolItem>[
  ToolItem(Icons.style_outlined, 'Flashcard', 'Notlarından bilgi kartları',
      builder: _flashcardPage),
  ToolItem(Icons.event_note_outlined, 'Çalışma Planı', 'Haftalık program', builder: _plannerPage),
  ToolItem(Icons.timer_outlined, 'Sınav Simülasyonu', 'Süreli deneme sınavı', builder: _examPage),
  ToolItem(Icons.insights_outlined, 'Başarı Haritası', 'Konu bazlı analiz', builder: _progressPage),
  ToolItem(Icons.picture_as_pdf_outlined, 'PDF ile Konuş', 'Belgeden soru-cevap', builder: _pdfPage),
  ToolItem(Icons.psychology_outlined, 'AI Koç', 'Kişisel öneriler', builder: _coachPage),
];

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Araçlar')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.15),
        itemCount: toolItems.length,
        itemBuilder: (context, i) {
          final t = toolItems[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (t.builder != null) {
                  Navigator.of(context).push(MaterialPageRoute(builder: t.builder!));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('${t.title} yakında eklenecek')));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PastelIcon(icon: t.icon, color: AppColors.pastels[i % AppColors.pastels.length]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                      Text(t.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
