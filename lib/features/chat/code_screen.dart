import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
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
import 'package:okakchat/features/agent/tool_definitions.dart';
import 'package:okakchat/features/agent/tools/tool_executor.dart';
import 'chat_provider.dart';
import 'chat_input.dart';
import 'model_settings_sheet.dart';
import 'message_bubble.dart' show TypingIndicator;

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});
  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _scrollCtrl = ScrollController();
  int? _focusedSnippetIndex;
  String _statusText = '';
  Timer? _statusTimer;
  int _elapsedSeconds = 0;
  StreamSubscription<Map<String, dynamic>>? _toolSub;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(codeProvider.notifier).loadModels();
      } catch (_) {}
      _toolSub = ref.read(codeProvider.notifier).toolCallStream.listen(_handleToolCall);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _statusTimer?.cancel();
    _toolSub?.cancel();
    super.dispose();
  }

  Future<void> _handleToolCall(Map<String, dynamic> toolCall) async {
    final settings = ref.read(codeProvider).codeSettings;
    final function = toolCall['function'] as Map<String, dynamic>?;
    if (function == null) return;

    final toolName = function['name'] as String;
    final args = jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    // Bypass (full) — никогда не спрашиваем, как в Claude/Codex.
    // ask/plan — спрашиваем всё неоднозначное (любые tool calls).
    final needsConfirm = settings.agentMode != 'full';
    if (needsConfirm) {
      final confirmed = await _showToolConfirm(toolName, args);
      if (!confirmed) {
        ref.read(codeProvider.notifier).continueWithToolResult(
          toolName, 'User skipped this action.',
          tools: agentTools,
        );
        return;
      }
    }

    setState(() => _processing = true);
    final genAtStart = ref.read(codeProvider.notifier).generationId;
    final executor = DesktopToolExecutor();
    final result = await executor.dispatch(toolName, args);
    if (!mounted) return;
    setState(() => _processing = false);

    if (ref.read(codeProvider.notifier).isCancelled) return;
    if (ref.read(codeProvider.notifier).generationId != genAtStart) return;

    ref.read(codeProvider.notifier).continueWithToolResult(
      toolName, result,
      tools: agentTools,
    );
  }

  Future<bool> _showToolConfirm(String toolName, Map<String, dynamic> args) async {
    final dangerous = toolName == 'execute_command';
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(dangerous ? '⚠ Run command?' : 'Allow: $toolName'),
            content: SingleChildScrollView(
              child: Text(
                args.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                style: GoogleFonts.dmMono(fontSize: 11),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Deny'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(dangerous ? 'Run' : 'Allow'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _updateStatus() {
    final state = ref.read(codeProvider);
    final lastMsg = state.messages.isNotEmpty ? state.messages.last : null;
    if (state.isLoading || (lastMsg?.isStreaming ?? false)) {
      final totalTokens = state.estimatedTokensUsed;
      final elapsed = _elapsedSeconds;
      final mins = elapsed ~/ 60;
      final secs = elapsed % 60;
      final timeStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
      if (state.codeSettings.agentMode == 'full') {
        _statusText = '\u00b7 Transfiguring\u2026 ($timeStr \u00b7 \u2191 ${_fmtTokens(totalTokens)} tokens)';
      } else if (state.codeSettings.agentMode == 'plan') {
        _statusText = '\u00b7 Planning\u2026 ($timeStr \u00b7 \u2191 ${_fmtTokens(totalTokens)} tokens)';
      } else {
        _statusText = '\u00b7 Thinking\u2026 ($timeStr \u00b7 \u2191 ${_fmtTokens(totalTokens)} tokens)';
      }
    } else {
      _statusText = '';
      _elapsedSeconds = 0;
      _statusTimer?.cancel();
      _statusTimer = null;
    }
    if (mounted) setState(() {});
  }

  String _fmtTokens(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
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
      final wasLoading = prev?.isLoading ?? false;
      final nowLoading = next.isLoading;
      if (!wasLoading && nowLoading) {
        _elapsedSeconds = 0;
        _statusTimer?.cancel();
        _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          _elapsedSeconds++;
          _updateStatus();
        });
        _updateStatus();
      } else if (wasLoading && !nowLoading) {
        _statusTimer?.cancel();
        _statusTimer = null;
        _updateStatus();
      }
    });

    final snippets = _extractSnippets(state.messages);
    final isMobile = MediaQuery.of(context).size.width < 700;

    // Determine particle formation based on agent state
    final formation = state.isLoading
        ? (state.codeSettings.agentMode == 'full'
            ? ParticleFormation.gear
            : state.codeSettings.agentMode == 'plan'
                ? ParticleFormation.brain
                : ParticleFormation.code)
        : ParticleFormation.none;

    return NotificationBannerStack(
      child: Stack(children: [
        Positioned.fill(
            child: AnimatedBackground(
              particleCount: 14,
              formation: formation,
              formationProgress: state.isLoading ? 0.6 : 0.0,
            )),
        Column(children: [
          _CodeTopBar(),
          Container(
              height: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),
          // Status bar during streaming or tool processing
          if (_statusText.isNotEmpty)
            _AgentStatusBar(text: _statusText),
          if (_processing && _statusText.isEmpty)
            _AgentStatusBar(text: '\u00b7 Executing tool\u2026'),
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
          if (_processing)
            Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.blue500.withValues(alpha: 0.15),
                color: AppTheme.blue400,
              ),
            ),
        ]),
      ]),
    );
  }
}

// ── Agent status bar ────────────────────────────────────────────────────

class _AgentStatusBar extends StatelessWidget {
  const _AgentStatusBar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.blue500.withValues(alpha: 0.08),
          border: Border(
              bottom: BorderSide(
                  color: AppTheme.blue500.withValues(alpha: 0.1))),
        ),
        child: Row(children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.blue400,
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.dmMono(
                  fontSize: 10,
                  color: AppTheme.blue300,
                  fontWeight: FontWeight.w500)),
        ]),
      );
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
                  '~${state.estimatedTokensUsed} / ${state.contextLimit} tokens',
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
            // Workspace folder picker
            _SmallIconBtn(
              icon: Icons.folder_outlined,
              tooltip: settings.workspacePath.isEmpty
                  ? 'Select workspace folder'
                  : settings.workspacePath.split('/').last,
              onTap: () async {
                final dir = await FilePicker.platform.getDirectoryPath();
                if (dir != null) {
                  ref.read(codeProvider.notifier).setCodeSettings(
                      settings.copyWith(workspacePath: dir));
                }
              },
            ),
            if (settings.workspacePath.isNotEmpty) ...[
              const SizedBox(width: 4),
              _PermChip(
                label: 'Files',
                icon: Icons.folder_open_rounded,
                active: settings.allowFileEdits,
                onTap: () => ref
                    .read(codeProvider.notifier)
                    .setCodeSettings(settings.copyWith(
                        allowFileEdits: !settings.allowFileEdits)),
              ),
            ],
            const SizedBox(width: 4),
            Tooltip(
              message: settings.allowCommands
                  ? 'Commands allowed'
                  : 'Commands blocked',
              child: _PermChip(
                label: 'Cmds',
                icon: Icons.terminal_rounded,
                active: settings.allowCommands,
                onTap: () => ref
                    .read(codeProvider.notifier)
                    .setCodeSettings(settings.copyWith(
                        allowCommands: !settings.allowCommands)),
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: settings.allowNetworkAccess
                  ? 'Network allowed'
                  : 'Network blocked',
              child: _PermChip(
                label: 'Net',
                icon: Icons.language_rounded,
                active: settings.allowNetworkAccess,
                onTap: () => ref
                    .read(codeProvider.notifier)
                    .setCodeSettings(settings.copyWith(
                        allowNetworkAccess:
                            !settings.allowNetworkAccess)),
              ),
            ),
            const SizedBox(width: 8),
            // Agent mode dropdown
            _ModeDropdown(
              value: settings.agentMode,
              onChanged: (v) => ref
                  .read(codeProvider.notifier)
                  .setCodeSettings(settings.copyWith(agentMode: v)),
            ),
            const SizedBox(width: 4),
            // Reasoning toggle
            _SmallIconBtn(
              icon: Icons.psychology_outlined,
              tooltip: settings.reasoningEnabled
                  ? 'Reasoning: on'
                  : 'Reasoning: off',
              active: settings.reasoningEnabled,
              onTap: () => ref
                  .read(codeProvider.notifier)
                  .setCodeSettings(settings.copyWith(
                      reasoningEnabled:
                          !settings.reasoningEnabled)),
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

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _modes = {'full': 'Full', 'plan': 'Plan', 'ask': 'Ask'};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
            color: AppTheme.blue500.withValues(alpha: 0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: AppTheme.surface1,
          style: GoogleFonts.dmMono(
              fontSize: 10,
              color: AppTheme.blue300,
              fontWeight: FontWeight.w600),
          items: _modes.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
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
      {required this.icon, required this.tooltip, required this.onTap, this.active});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool? active;

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
                color: widget.active == true
                    ? AppTheme.blue500.withValues(alpha: 0.15)
                    : _hovered
                        ? AppTheme.blue500.withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon,
                  size: 16,
                  color: widget.active == true ? AppTheme.blue400 : AppTheme.textMid),
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
    if (message.role == 'tool') {
      return _ToolCallInline(message: message);
    }
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
                ? const TypingIndicator()
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
              tools: agentTools,
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
    'Set up GitHub Actions CI',
    'Write a GitHub workflow',
    'Review this PR for issues',
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

// ── Tool call inline display ────────────────────────────────────────────

class _ToolCallInline extends StatefulWidget {
  const _ToolCallInline({required this.message});
  final ChatMessage message;

  @override
  State<_ToolCallInline> createState() => _ToolCallInlineState();
}

class _ToolCallInlineState extends State<_ToolCallInline> {
  bool _expanded = false;

  String _detectToolName(String content) {
    if (content.contains('write_file') || content.contains('edit_file')) return 'Edit';
    if (content.contains('execute_command')) return 'Run';
    if (content.contains('read_file') || content.contains('grep')) return 'Read';
    if (content.contains('web_search') || content.contains('fetch')) return 'Search';
    return 'Tool';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: GestureDetector(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface1.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.blue500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.terminal_rounded,
                      size: 12, color: AppTheme.blue400),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          _detectToolName(widget.message.content),
                          style: GoogleFonts.dmMono(
                              fontSize: 10,
                              color: AppTheme.blue300,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 12,
                          color: AppTheme.textLow,
                        ),
                      ]),
                      if (_expanded) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.message.content,
                            style: GoogleFonts.dmMono(
                                fontSize: 10,
                                color: AppTheme.textMid,
                                height: 1.5),
                          ),
                        ),
                      ] else
                        Text(
                          widget.message.content.length > 60
                              ? '${widget.message.content.substring(0, 60)}\u2026'
                              : widget.message.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmMono(
                              fontSize: 10, color: AppTheme.textLow),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Data model ────────────────────────────────────────────────────────────

class _CodeSnippet {
  const _CodeSnippet({required this.language, required this.code});
  final String language;
  final String code;
}
