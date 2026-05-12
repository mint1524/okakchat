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
import 'chat_provider.dart';
import 'chat_input.dart';
import 'model_selector.dart';
import 'model_settings_sheet.dart';

// ── Entry point ───────────────────────────────────────────────────────────

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});
  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _scrollCtrl = ScrollController();
  int? _focusedCodeBlockIndex;

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
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Extract all code blocks from messages for the right panel
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
      if (snippets.isNotEmpty) break; // show snippets from latest reply
    }
    return snippets;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length != prev?.messages.length) {
        _scrollToBottom();
        setState(() => _focusedCodeBlockIndex = null);
      }
    });

    final snippets = _extractSnippets(state.messages);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Stack(children: [
      const Positioned.fill(child: AnimatedBackground(particleCount: 14)),
      Column(children: [
        _CodeTopBar(state: state),
        Container(height: 1, color: AppTheme.blue500.withValues(alpha: 0.1)),
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
                  focusedIndex: _focusedCodeBlockIndex,
                  onFocus: (i) => setState(() => _focusedCodeBlockIndex = i),
                ),
        ),
        _GlassCodeInput(onSend: _scrollToBottom),
      ]),
    ]);
  }
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
          // ── Left: conversation ────────────────────────────────────────
          SizedBox(
            width: 380,
            child: _ConversationPanel(
              state: state,
              scrollCtrl: scrollCtrl,
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: AppTheme.blue500.withValues(alpha: 0.12),
          ),
          // ── Right: code output ────────────────────────────────────────
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

// ── Mobile: stacked tabs ──────────────────────────────────────────────────

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
        // Tab row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: AppTheme.bg.withValues(alpha: 0.6),
          child: Row(children: [
            _Tab(
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                selected: !_showCode,
                onTap: () => setState(() => _showCode = false)),
            const SizedBox(width: 8),
            _Tab(
                label: 'Code',
                icon: Icons.code_rounded,
                selected: _showCode,
                onTap: () => setState(() => _showCode = true)),
          ]),
        ),
        Container(height: 1, color: AppTheme.blue500.withValues(alpha: 0.08)),
        Expanded(
          child: _showCode
              ? _CodeOutputPanel(
                  snippets: widget.snippets,
                  isLoading: widget.state.isLoading,
                )
              : _ConversationPanel(
                  state: widget.state,
                  scrollCtrl: widget.scrollCtrl,
                ),
        ),
      ]);
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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue500.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.blue500.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 14,
                color: selected ? AppTheme.blue400 : AppTheme.textMid),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        selected ? AppTheme.blue300 : AppTheme.textMid)),
          ]),
        ),
      );
}

// ── Conversation panel ────────────────────────────────────────────────────

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel(
      {required this.state, required this.scrollCtrl});
  final ChatState state;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (state.messages.isEmpty) {
      return const _CodeEmptyState();
    }
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      itemCount: state.messages.length,
      itemBuilder: (_, i) =>
          _CompactMessage(message: state.messages[i]),
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
    final snippet =
        displayIndex < snippets.length ? snippets[displayIndex] : snippets.last;

    return Column(children: [
      // Snippet tabs (if multiple)
      if (snippets.length > 1)
        _SnippetTabs(
          snippets: snippets,
          selectedIndex: displayIndex,
          onSelect: onFocus ?? (_) {},
        ),
      // Code view
      Expanded(
        child: _SnippetView(snippet: snippet),
      ),
    ]);
  }
}

class _SnippetTabs extends StatelessWidget {
  const _SnippetTabs(
      {required this.snippets,
      required this.selectedIndex,
      required this.onSelect});
  final List<_CodeSnippet> snippets;
  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface1.withValues(alpha: 0.8),
          border: Border(
            bottom: BorderSide(color: AppTheme.blue500.withValues(alpha: 0.1)),
          ),
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
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? AppTheme.blue400 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  snippets[i].language,
                  style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: sel ? AppTheme.blue300 : AppTheme.textMid,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
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
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.surface2.withValues(alpha: 0.5),
            border: Border(
              bottom:
                  BorderSide(color: AppTheme.blue500.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        // Code content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: HighlightView(
              snippet.code,
              language: snippet.language,
              theme: atomOneDarkTheme,
              padding: const EdgeInsets.all(20),
              textStyle: GoogleFonts.dmMono(fontSize: 13, height: 1.6),
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isLoading ? Icons.hourglass_top_rounded : Icons.code_off_rounded,
              size: 28,
              color: AppTheme.textMid,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isLoading ? 'Generating…' : 'No code yet',
            style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask Claude to write or explain code.\nCode blocks will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 13, color: AppTheme.textLow),
          ),
        ]),
      );
}

// ── Compact message (left panel) ──────────────────────────────────────────

class _CompactMessage extends StatelessWidget {
  const _CompactMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) return _CompactUserMsg(content: message.content);
    if (message.role == 'tool') return const SizedBox.shrink();
    return _CompactAssistantMsg(message: message);
  }
}

class _CompactUserMsg extends StatelessWidget {
  const _CompactUserMsg({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: AppTheme.blue700.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.3)),
          ),
          child: Text(content,
              style: GoogleFonts.sora(
                  fontSize: 13,
                  color: AppTheme.textHigh,
                  height: 1.5)),
        ),
      );
}

class _CompactAssistantMsg extends StatelessWidget {
  const _CompactAssistantMsg({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.06),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.1)),
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? _MiniTypingIndicator()
                  : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.sora(
                            fontSize: 13,
                            color: AppTheme.textHigh,
                            height: 1.6),
                        code: GoogleFonts.dmMono(
                            fontSize: 12, color: AppTheme.blue300),
                        h1: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textHigh),
                        h2: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textHigh),
                        h3: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textHigh),
                        listBullet: GoogleFonts.sora(
                            fontSize: 13, color: AppTheme.blue400),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF0D1117),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        codeblockPadding: const EdgeInsets.all(12),
                      ),
                    ),
            ),
          ),
        ),
      );
}

class _MiniTypingIndicator extends StatefulWidget {
  @override
  State<_MiniTypingIndicator> createState() => _MiniTypingIndicatorState();
}

class _MiniTypingIndicatorState extends State<_MiniTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 18,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final t = ((_ctrl.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
                final dy = t < 0.4 ? -4 * (t / 0.4)
                    : t < 0.7 ? -4 * (1 - (t - 0.4) / 0.3)
                    : 0.0;
                final op = 0.3 + 0.7 *
                    (t < 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.blue400.withValues(alpha: op),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
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
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          size: 13,
          color: _copied ? AppTheme.blue400 : AppTheme.textMid,
        ),
        const SizedBox(width: 5),
        Text(
          _copied ? 'Copied!' : 'Copy',
          style: GoogleFonts.sora(
            fontSize: 11,
            color: _copied ? AppTheme.blue400 : AppTheme.textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
      ]),
    ),
  );
}

// ── Top bar ───────────────────────────────────────────────────────────────

class _CodeTopBar extends ConsumerWidget {
  const _CodeTopBar({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: AppTheme.bg.withValues(alpha: 0.7)),
            child: Row(children: [
              // Code mode badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.blue500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.blue500.withValues(alpha: 0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.code_rounded,
                      size: 14, color: AppTheme.blue400),
                  const SizedBox(width: 6),
                  Text('Code Mode',
                      style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.blue300)),
                ]),
              ),
              const SizedBox(width: 10),
              // Model selector
              Expanded(
                child: ModelSelector(
                  selectedModel: state.selectedModel,
                  models: state.models,
                  onSelected: (m) =>
                      ref.read(chatProvider.notifier).selectModel(m),
                ),
              ),
              const SizedBox(width: 8),
              // Switch to Chat
              _TopBarChip(
                label: 'Chat',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () =>
                    ref.read(chatProvider.notifier).setMode('chat'),
              ),
              const SizedBox(width: 6),
              // Settings
              _SettingsBtn(
                badge: state.systemPrompt != null &&
                    state.systemPrompt!.isNotEmpty,
                onTap: () => ModelSettingsSheet.show(context),
              ),
            ]),
          ),
        ),
      );
}

class _TopBarChip extends StatelessWidget {
  const _TopBarChip(
      {required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: AppTheme.textMid),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w400)),
          ]),
        ),
      );
}

class _SettingsBtn extends StatelessWidget {
  const _SettingsBtn({required this.badge, required this.onTap});
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(Icons.tune_rounded, size: 18, color: AppTheme.textMid),
            if (badge)
              Positioned(
                right: 5, top: 5,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: AppTheme.blue400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ── Glass input area (code-specific, pre-fills with coding system prompt) ─

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
                    color: AppTheme.blue500.withValues(alpha: 0.1)),
              ),
            ),
            child: ChatInput(onSend: onSend),
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────

class _CodeEmptyState extends StatefulWidget {
  const _CodeEmptyState();
  @override
  State<_CodeEmptyState> createState() => _CodeEmptyStateState();
}

class _CodeEmptyStateState extends State<_CodeEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _suggestions = [
    'Write a REST API endpoint',
    'Explain this algorithm',
    'Debug my function',
    'Refactor for readability',
  ];

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.blue500
                          .withValues(alpha: 0.08 + 0.12 * _pulse.value),
                      blurRadius: 28 + 20 * _pulse.value,
                    )
                  ],
                ),
                child: child,
              ),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.blue900,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.blue500.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.terminal_rounded,
                    size: 32, color: AppTheme.blue400),
              ),
            ),
            const SizedBox(height: 20),
            Text('Code assistant',
                style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textHigh,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('Ask Claude to write, review, or explain code.',
                style:
                    GoogleFonts.sora(fontSize: 13, color: AppTheme.textMid)),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map((s) => _SuggestionChip(label: s))
                  .toList(),
            ),
          ]),
        ),
      );
}

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onTap: () =>
            ref.read(chatProvider.notifier).sendMessage(label),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.15)),
          ),
          child: Text(label,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w400)),
        ),
      );
}

// ── Data model ────────────────────────────────────────────────────────────

class _CodeSnippet {
  const _CodeSnippet({required this.language, required this.code});
  final String language;
  final String code;
}
