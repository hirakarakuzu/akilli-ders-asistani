import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../api.dart';
import '../auth.dart';
import '../core/utils/activity.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/chat_context.dart';
import '../core/utils/default_subjects.dart';
import '../core/widgets/brand.dart' show owlAsset;
import '../db.dart';
import '../widgets.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String title;
  const ChatScreen({super.key, required this.conversationId, required this.title});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<DbRow> msgs = [];
  bool sending = false;
  String? error;
  String? lastText;

  ChatContextInfo? info;

  List<String> get _suggestions => suggestionsFor(info?.subjectName);

  Future<void> _loadInfo() async {
    try {
      final i = await ChatContext.info(widget.conversationId);
      if (mounted) setState(() => info = i);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadInfo();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await Repo.messages(widget.conversationId);
    if (!mounted) return;
    setState(() => msgs = m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send({String? retry}) async {
    final text = (retry ?? _ctrl.text).trim();
    if (text.isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    if (retry == null) {
      final first = msgs.isEmpty;
      _ctrl.clear();
      await Repo.addMessage(widget.conversationId, 'user', text);
      await ActivityLog.add(Session.userId, 90, 'sohbet');
      if (first) {
        await Repo.renameConversation(
            widget.conversationId, text.length > 40 ? '${text.substring(0, 40)}...' : text);
      }
      await _load();
    }
    try {
      // Son mesaj şu anki soru ise geçmişten çıkar.
      final history = [...msgs];
      if (history.isNotEmpty && history.last['role'] == 'user' && history.last['content'] == text) {
        history.removeLast();
      }
      final prompt = await ChatContext.build(
        conversationId: widget.conversationId,
        question: text,
        history: history,
        info: info,
      );
      final reply = await Api.chat(prompt);
      await Repo.addMessage(widget.conversationId, 'assistant', reply);
      lastText = null;
    } on ApiException catch (e) {
      error = e.message;
      lastText = text;
    } catch (_) {
      error = 'Beklenmeyen bir hata oluştu.';
      lastText = text;
    }
    if (!mounted) return;
    setState(() => sending = false);
    await _load();
  }

  Widget _avatar({double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
      child: Padding(padding: EdgeInsets.all(size * 0.14), child: Image.asset(owlAsset)),
    );
  }

  Widget _bubble(DbRow m) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final isUser = m['role'] == 'user';
    final content = m['content'] as String;
    final maxW = MediaQuery.of(context).size.width;

    if (isUser) {
      return FadeSlideIn(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 6, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: maxW * 0.82),
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.brandGradientDark : AppColors.brandGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(content, style: const TextStyle(color: AppColors.white, height: 1.4, fontSize: 15)),
          ),
        ),
      );
    }

    final md = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(color: cs.onSurface, height: 1.45, fontSize: 15),
      code: TextStyle(backgroundColor: cs.surfaceContainerHigh, color: cs.onSurface, fontSize: 13),
      codeblockDecoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
    );

    return FadeSlideIn(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            _avatar(),
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW * 0.8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: MarkdownBody(data: content, selectable: true, styleSheet: md),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(content: Text('Kopyalandı'), duration: Duration(seconds: 1)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('Kopyala', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _typing() {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _avatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const _TypingDots(),
          ),
        ]),
      ),
    );
  }

  Widget _welcome() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeSlideIn(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _avatar(size: 72),
            const SizedBox(height: 20),
            Text(
                info == null || info!.isGeneral
                    ? 'Merhaba! Ne öğrenmek istersin?'
                    : '${info!.subjectName} hakkında ne öğrenmek istersin?', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Dersinle ilgili bir soru sor ya da aşağıdan birini seç.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () {
                    _ctrl.text = s;
                    _send();
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
          Text(info?.subtitle ?? 'Yapay zekâ asistanı', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: msgs.isEmpty && !sending
              ? _welcome()
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  children: [
                    for (final m in msgs) _bubble(m),
                    if (sending) _typing(),
                    if (error != null)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: cs.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(child: Text(error!, style: TextStyle(color: cs.onErrorContainer))),
                          TextButton(
                              onPressed: lastText == null ? null : () => _send(retry: lastText),
                              child: const Text('Tekrar dene')),
                        ]),
                      ),
                  ],
                ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Bir soru yaz...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: cs.primary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: cs.secondary,
                    foregroundColor: AppColors.white,
                    fixedSize: const Size(48, 48),
                  ),
                  onPressed: sending ? null : () => _send(),
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Transform.translate(
              offset: Offset(0, -5 * math.sin((((_c.value - i * 0.18) % 1) + 1) % 1 * math.pi)),
              child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
          ),
      ]),
    );
  }
}
