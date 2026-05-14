import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/widgets/animated_background.dart';
import 'package:okakchat/core/widgets/notification_banner.dart';
import 'chat_provider.dart';
import 'chat_input.dart';
import 'model_settings_sheet.dart';
import 'message_bubble.dart' show _TypingIndicator;

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});
  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _scrollCtrl = ScrollController();
  int? _focusedSnippetIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(codeProvider.notifier).loadModels();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<_CodeSnippet> _extractSnippets(List<ChatMessage> messages) {
    final snippets = <_CodeSnippet>[];
    for (final msg in messages.reversed) {
      if (msg.role != 'assistant') continue;
      final matches =
          RegExp(r'```(\w*)\n([\s\S]*?)```').allMatches(msg.content);
      for (final m in matches.toList().reversed) {
        snippets.insert(
          0,
          _CodeSnippet(
            language: m.group(1)?.isNotEmpty == true
                ? m.group(1)!
                : 'plaintext',
            code: m.group(2) ?? '',
          ),
        );
      }
      if (snippets.isNotEmpty) break;
    }
    return snippets;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(codeProvider);
    ref.listen(codeProvider, (prev, next) {
      if (next.messages.length != prev?.messages.length) {
        _scrollToBottom();
        setState(() => _focusedSnippetIndex = null);
      }
    });

    final snippets = _extractSnippets(state.messages);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return NotificationBannerStack(
      child: Stack(children: [
        const Positioned.fill(
            child: AnimatedBackground(particleCount: 14)),
        Column(children: [
          _CodeTopBar(),
          Container(
              height: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
          Expanded(
            child: isMobile
                ? _MobileLayout(
                    state: state,
                    scrollCtrl: _scrollCtrl,
                    snippets: snippets,
                  )
                : _DesktopLayout(
                    state: state,
                    scrollCtrl: _scrollCtrl,
                    snippets: snippets,
                    focusedIndex: _focusedSnippetIndex,
                    onFocus: (i) =>
                        setState(() => _focusedSnippetIndex = i),
                  ),
          ),
          _GlassCodeInput(onSend: _scrollToBottom),
        ]),
      ]),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _CodeTopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(codeProvider);
    final settings = state.codeSettings;
    final fill = state.contextFillFraction;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration:
              BoxDecoration(color: AppTheme.bg.withValues(alpha: 0.7)),
          child: Row(children: [
            // Code mode badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.code_rounded,
                    size: 13, color: AppTheme.blue400),
                const SizedBox(width: 5),
                Text('Code',
                    style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.blue300)),
              ]),
            ),
            const SizedBox(width: 10),
            // Context fill bar
            Tooltip(
              message:
                  '~${state.estimatedTokensUsed} / ${state.maxTokens} tokens',
              child: SizedBox(
                width: 60,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(fill * 100).round()}% ctx',
                      style: GoogleFonts.sora(
                          fontSize: 9,
                          color: fill > 0.8
                              ? const Color(0xFFEF4444)
                              : AppTheme.textLow),
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fill,
                        backgroundColor:
                            AppTheme.surface2,
                        valueColor: AlwaysStoppedAnimation(
                          fill > 0.8
                              ? const Color(0xFFEF4444)
                              : fill > 0.6
                                  ? const Color(0xFFF59E0B)
                                  : AppTheme.blue400,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Permission chips
            _PermChip(
              label: 'Files',
              icon: Icons.folder_open_rounded,
              active: settings.allowFileEdits,
              onTap: () => ref
                  .read(codeProvider.notifier)
                  .setCodeSettings(settings.copyWith(
                      allowFileEdits: !settings.allowFileEdits)),
            ),
            const SizedBox(width: 4),
            _PermChip(
              label: 'Cmds',
              icon: Icons.terminal_rounded,
              active: settings.allowCommands,
              onTap: () => ref
                  .read(codeProvider.notifier)
                  .setCodeSettings(settings.copyWith(
                      allowCommands: !settings.allowCommands)),
            ),
            const Spacer(),
            // New chat
            _SmallIconBtn(
              icon: Icons.add_rounded,
              tooltip: 'New session',
              onTap: () =>
                  ref.read(codeProvider.notifier).newChat(),
            ),
            const SizedBox(width: 4),
            // Settings
            _SmallIconBtn(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () => ModelSettingsSheet.show(context,
                  provider: codeProvider),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PermChip extends StatelessWidget {
  const _PermChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.blue500.withValues(alpha: 0.18)
                : AppTheme.surface2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? AppTheme.blue500.withValues(alpha: 0.4)
                  : AppTheme.blue500.withValues(alpha: 0.1),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 10,
                color: active ? AppTheme.blue400 : AppTheme.textMid),
            const SizedBox(width: 3),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 9,
                    color: active
                        ? AppTheme.blue300
                        : AppTheme.textMid,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ]),
        ),
      );
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit:  (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon,
                  size: 16, color: AppTheme.textMid),
            ),
          ),
        ),
      );
}

// ── Desktop 2-panel layout ────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.state,
    required this.scrollCtrl,
    required this.snippets,
    required this.focusedIndex,
    required this.onFocus,
  });
  final ChatState state;
  final ScrollController scrollCtrl;
  final List<_CodeSnippet> snippets;
  final int? focusedIndex;
  final void Function(int?) onFocus;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 360,
            child: _ConversationPanel(
                state: state, scrollCtrl: scrollCtrl),
          ),
          Container(
              width: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
          Expanded(
            child: _CodeOutputPanel(
              snippets: snippets,
              focusedIndex: focusedIndex,
              onFocus: onFocus,
              isLoading: state.isLoading,
            ),
          ),
        ],
      );
}

// ── Mobile layout ─────────────────────────────────────────────────────────

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({
    required this.state,
    required this.scrollCtrl,
    required this.snippets,
  });
  final ChatState state;
  final ScrollController scrollCtrl;
  final List<_CodeSnippet> snippets;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  bool _showCode = false;

  @override
  Widget build(BuildContext context) => Column(children: [
        _TabRow(
          showCode: _showCode,
          onToggle: (v) => setState(() => _showCode = v),
        ),
        Expanded(
          child: _showCode
              ? _CodeOutputPanel(
                  snippets: widget.snippets,
                  isLoading: widget.state.isLoading)
              : _ConversationPanel(
                  state: widget.state,
                  scrollCtrl: widget.scrollCtrl),
        ),
      ]);
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.showCode, required this.onToggle});
  final bool showCode;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        color: AppTheme.bg.withValues(alpha: 0.6),
        child: Row(children: [
          _Tab(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              selected: !showCode,
              onTap: () => onToggle(false)),
          const SizedBox(width: 8),
          _Tab(
              label: 'Code',
              icon: Icons.code_rounded,
              selected: showCode,
              onTap: () => onToggle(true)),
        ]),
      );
}

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(
              horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue500.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? AppTheme.blue500.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 13,
                color: selected
                    ? AppTheme.blue400
                    : AppTheme.textMid),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected
                        ? AppTheme.blue300
                        : AppTheme.textMid)),
          ]),
        ),
      );
}

// ── Conversation panel (compact messages) ────────────────────────────────

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel(
      {required this.state, required this.scrollCtrl});
  final ChatState state;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (state.messages.isEmpty) return const _CodeEmptyState();
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      itemCount: state.messages.length,
      itemBuilder: (_, i) =>
          _CompactMessage(message: state.messages[i]),
    );
  }
}

class _CompactMessage extends StatelessWidget {
  const _CompactMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == 'tool') return const SizedBox.shrink();
    if (message.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 7),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65),
          decoration: BoxDecoration(
            color: AppTheme.blue700.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(3),
            ),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.3)),
          ),
          child: Text(message.content,
              style: GoogleFonts.sora(
                  fontSize: 13,
                  color: AppTheme.textHigh,
                  height: 1.5)),
        ),
      );
    }
    // Assistant
    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppTheme.blue500.withValues(alpha: 0.06),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.1)),
            ),
            child: message.isStreaming && message.content.isEmpty
                ? const _TypingIndicator()
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.sora(
                          fontSize: 13,
                          color: AppTheme.textHigh,
                          height: 1.6),
                      code: GoogleFonts.dmMono(
                          fontSize: 12,
                          color: AppTheme.blue300),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      codeblockPadding: const EdgeInsets.all(10),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Code output panel ─────────────────────────────────────────────────────

class _CodeOutputPanel extends StatelessWidget {
  const _CodeOutputPanel({
    required this.snippets,
    this.focusedIndex,
    this.onFocus,
    this.isLoading = false,
  });
  final List<_CodeSnippet> snippets;
  final int? focusedIndex;
  final void Function(int?)? onFocus;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (snippets.isEmpty) {
      return _NoCodePlaceholder(isLoading: isLoading);
    }
    final displayIndex = focusedIndex ?? snippets.length - 1;
    final snippet = displayIndex < snippets.length
        ? snippets[displayIndex]
        : snippets.last;

    return Column(children: [
      if (snippets.length > 1)
        _SnippetTabs(
          snippets: snippets,
          selectedIndex: displayIndex,
          onSelect: onFocus ?? (_) {},
        ),
      Expanded(child: _SnippetView(snippet: snippet)),
    ]);
  }
}

class _SnippetTabs extends StatelessWidget {
  const _SnippetTabs({
    required this.snippets,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<_CodeSnippet> snippets;
  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.surface1.withValues(alpha: 0.8),
          border: Border(
              bottom: BorderSide(
                  color: AppTheme.blue500.withValues(alpha: 0.1))),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: snippets.length,
          itemBuilder: (_, i) {
            final sel = i == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel
                          ? AppTheme.blue400
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(snippets[i].language,
                    style: GoogleFonts.dmMono(
                        fontSize: 11,
                        color: sel
                            ? AppTheme.blue300
                            : AppTheme.textMid,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
            );
          },
        ),
      );
}

class _SnippetView extends StatelessWidget {
  const _SnippetView({required this.snippet});
  final _CodeSnippet snippet;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface2.withValues(alpha: 0.5),
            border: Border(
                bottom: BorderSide(
                    color:
                        AppTheme.blue500.withValues(alpha: 0.1))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.3)),
              ),
              child: Text(snippet.language,
                  style: GoogleFonts.dmMono(
                      fontSize: 11,
                      color: AppTheme.blue300,
                      fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            _CopyCodeBtn(code: snippet.code),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: HighlightView(
              snippet.code,
              language: snippet.language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(20),
              textStyle:
                  GoogleFonts.dmMono(fontSize: 13, height: 1.6),
            ),
          ),
        ),
      ]);
}

class _NoCodePlaceholder extends StatelessWidget {
  const _NoCodePlaceholder({this.isLoading = false});
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.code_off_rounded,
              size: 26,
              color: AppTheme.textMid,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isLoading ? 'Generating…' : 'No code yet',
            style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid),
          ),
          const SizedBox(height: 5),
          Text(
            'Code blocks from the AI\nwill appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
                fontSize: 12, color: AppTheme.textLow),
          ),
        ]),
      );
}

// ── Copy code button ──────────────────────────────────────────────────────

class _CopyCodeBtn extends StatefulWidget {
  const _CopyCodeBtn({required this.code});
  final String code;

  @override
  State<_CopyCodeBtn> createState() => _CopyCodeBtnState();
}

class _CopyCodeBtnState extends State<_CopyCodeBtn> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.code));
          setState(() => _copied = true);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _copied = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _copied
                ? AppTheme.blue500.withValues(alpha: 0.2)
                : AppTheme.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _copied
                  ? AppTheme.blue500.withValues(alpha: 0.4)
                  : AppTheme.blue500.withValues(alpha: 0.12),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 12,
              color: _copied ? AppTheme.blue400 : AppTheme.textMid,
            ),
            const SizedBox(width: 5),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: GoogleFonts.sora(
                  fontSize: 11,
                  color: _copied
                      ? AppTheme.blue400
                      : AppTheme.textMid,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      );
}

// ── Glass code input ──────────────────────────────────────────────────────

class _GlassCodeInput extends StatelessWidget {
  const _GlassCodeInput({required this.onSend});
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bg.withValues(alpha: 0.75),
              border: Border(
                  top: BorderSide(
                      color: AppTheme.blue500.withValues(alpha: 0.1))),
            ),
            child: ChatInput(
              onSend: onSend,
              provider: codeProvider,
            ),
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────

class _CodeEmptyState extends ConsumerWidget {
  const _CodeEmptyState();

  static const _suggestions = [
    'Write a REST API endpoint',
    'Explain this algorithm',
    'Debug my function',
    'Refactor for readability',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.blue900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.terminal_rounded,
                  size: 30, color: AppTheme.blue400),
            ),
            const SizedBox(height: 18),
            Text('Code assistant',
                style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHigh,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('Ask Claude to write, review, or explain code.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                    fontSize: 13, color: AppTheme.textMid)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map((s) => GestureDetector(
                        onTap: () => ref
                            .read(codeProvider.notifier)
                            .sendMessage(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.blue500
                                    .withValues(alpha: 0.15)),
                          ),
                          child: Text(s,
                              style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: AppTheme.textMid)),
                        ),
                      ))
                  .toList(),
            ),
          ]),
        ),
      );
}

// ── Data model ────────────────────────────────────────────────────────────

class _CodeSnippet {
  const _CodeSnippet({required this.language, required this.code});
  final String language;
  final String code;
}
