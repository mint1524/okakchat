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
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:okakchat/core/widgets/notification_banner.dart';
import 'package:okakchat/features/agent/tool_definitions.dart';
import 'package:okakchat/features/agent/tools/tool_executor.dart';
import 'agent_status_strip.dart';
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
  Timer? _statusTimer;
  int _elapsedSeconds = 0;
  StreamSubscription<Map<String, dynamic>>? _toolSub;
  bool _processing = false;
  String? _currentToolName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(codeProvider.notifier).loadModels();
      } catch (_) {}
      _toolSub = ref
          .read(codeProvider.notifier)
          .toolCallStream
          .listen(_handleToolCall);
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
    final args =
        jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    // Bypass (full) — никогда не спрашиваем, как в Claude/Codex.
    // ask/plan — спрашиваем всё неоднозначное (любые tool calls).
    AppLogger.tool('inbound $toolName  mode=${settings.agentMode}');
    final needsConfirm = settings.agentMode != 'full';
    if (needsConfirm) {
      AppLogger.tap('Tool confirm dialog — $toolName');
      final confirmed = await _showToolConfirm(toolName, args);
      AppLogger.tap('Tool confirm → ${confirmed ? "ALLOW" : "SKIP"}');
      if (!confirmed) {
        ref.read(codeProvider.notifier).continueWithToolResult(
              toolName,
              'User skipped this action.',
              args: args,
              tools: agentTools,
            );
        return;
      }
    }

    setState(() {
      _processing = true;
      _currentToolName = toolName;
    });
    final genAtStart = ref.read(codeProvider.notifier).generationId;
    final executor = DesktopToolExecutor();
    // Race dispatch against cancel token — Stop button wins immediately.
    final cancelToken = Completer<String>();
    ref.read(codeProvider.notifier).registerToolCancelToken(cancelToken);
    final String result;
    try {
      result = await Future.any([
        executor.dispatch(toolName, args),
        cancelToken.future,
      ]);
    } finally {
      ref.read(codeProvider.notifier).clearToolCancelToken();
    }
    if (!mounted) return;
    setState(() {
      _processing = false;
      _currentToolName = null;
    });

    if (ref.read(codeProvider.notifier).isCancelled) return;
    if (ref.read(codeProvider.notifier).generationId != genAtStart) return;

    ref.read(codeProvider.notifier).continueWithToolResult(
          toolName,
          result,
          args: args,
          tools: agentTools,
        );
  }

  Future<bool> _showToolConfirm(
      String toolName, Map<String, dynamic> args) async {
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
    final running = state.isLoading || (lastMsg?.isStreaming ?? false);
    if (!running) {
      _elapsedSeconds = 0;
      _statusTimer?.cancel();
      _statusTimer = null;
    }
    if (mounted) setState(() {});
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
            language:
                m.group(1)?.isNotEmpty == true ? m.group(1)! : 'plaintext',
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

    // ── Derive current agent phase for the bottom status strip ───────
    final lastMsg = state.messages.isNotEmpty ? state.messages.last : null;
    final assistantStreaming =
        lastMsg?.role == 'assistant' && (lastMsg?.isStreaming ?? false);
    final AgentPhase phase;
    final String phaseLabel;
    if (_processing) {
      switch (_currentToolName) {
        case 'read_file':
          phase = AgentPhase.reading;
          phaseLabel = 'Reading file';
        case 'write_file':
          phase = AgentPhase.writing;
          phaseLabel = 'Writing file';
        case 'edit_file':
          phase = AgentPhase.editing;
          phaseLabel = 'Editing file';
        case 'execute_command':
          phase = AgentPhase.running;
          phaseLabel = 'Running command';
        case 'list_directory':
          phase = AgentPhase.listing;
          phaseLabel = 'Listing directory';
        case 'search_files':
          phase = AgentPhase.searching;
          phaseLabel = 'Searching files';
        default:
          phase = AgentPhase.running;
          phaseLabel = 'Waiting for tool';
      }
    } else if (assistantStreaming) {
      if ((lastMsg?.content.isEmpty ?? true)) {
        phase = AgentPhase.thinking;
        phaseLabel =
            state.codeSettings.agentMode == 'plan' ? 'Planning' : 'Thinking';
      } else {
        phase = AgentPhase.streaming;
        phaseLabel = 'Responding';
      }
    } else {
      phase = AgentPhase.idle;
      phaseLabel = '';
    }
    final showStatus = phase != AgentPhase.idle;

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
                  ),
          ),
          // Agent status strip — sits directly above the input, like
          // Claude Code / OpenCode.
          // AnimatedCrossFade keeps AgentStatusStrip mounted → orbit animation
          // never resets between tool→think transitions (no visual jump).
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: showStatus
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: AgentStatusStrip(
              phase: phase,
              label: phaseLabel,
              elapsedSec: _elapsedSeconds,
              tokens: state.estimatedTokensUsed,
              onCancel: () => ref.read(codeProvider.notifier).cancel(),
            ),
            secondChild: const SizedBox.shrink(),
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
          decoration: BoxDecoration(color: AppTheme.bg.withValues(alpha: 0.7)),
          child: Row(children: [
            // Code mode badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
                border:
                    Border.all(color: AppTheme.blue500.withValues(alpha: 0.35)),
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
                        backgroundColor: AppTheme.surface2,
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
                  ref
                      .read(codeProvider.notifier)
                      .setCodeSettings(settings.copyWith(workspacePath: dir));
                }
              },
            ),
            if (settings.workspacePath.isNotEmpty) ...[
              const SizedBox(width: 4),
              _PermChip(
                label: 'Files',
                icon: Icons.folder_open_rounded,
                active: settings.allowFileEdits,
                onTap: () => ref.read(codeProvider.notifier).setCodeSettings(
                    settings.copyWith(
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
                onTap: () => ref.read(codeProvider.notifier).setCodeSettings(
                    settings.copyWith(allowCommands: !settings.allowCommands)),
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
                onTap: () => ref.read(codeProvider.notifier).setCodeSettings(
                    settings.copyWith(
                        allowNetworkAccess: !settings.allowNetworkAccess)),
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
              onTap: () => ref.read(codeProvider.notifier).setCodeSettings(
                  settings.copyWith(
                      reasoningEnabled: !settings.reasoningEnabled)),
            ),
            const Spacer(),
            // New chat
            _SmallIconBtn(
              icon: Icons.add_rounded,
              tooltip: 'New session',
              onTap: () => ref.read(codeProvider.notifier).newChat(),
            ),
            const SizedBox(width: 4),
            // Settings
            _SmallIconBtn(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () =>
                  ModelSettingsSheet.show(context, provider: codeProvider),
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
        border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
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
                size: 10, color: active ? AppTheme.blue400 : AppTheme.textMid),
            const SizedBox(width: 3),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 9,
                    color: active ? AppTheme.blue300 : AppTheme.textMid,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.active});
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
          onExit: (_) => setState(() => _hovered = false),
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
                  color: widget.active == true
                      ? AppTheme.blue400
                      : AppTheme.textMid),
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
  });
  final ChatState state;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) =>
      // Full-width conversation (Claude Code-style transcript). The right
      // code-output panel was removed because the agent now uses tools
      // (write_file/edit_file) directly instead of printing code blocks.
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _ConversationPanel(state: state, scrollCtrl: scrollCtrl),
        ),
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
                  snippets: widget.snippets, isLoading: widget.state.isLoading)
              : _ConversationPanel(
                  state: widget.state, scrollCtrl: widget.scrollCtrl),
        ),
      ]);
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.showCode, required this.onToggle});
  final bool showCode;
  final void Function(bool) onToggle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
                color: selected ? AppTheme.blue400 : AppTheme.textMid),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.blue300 : AppTheme.textMid)),
          ]),
        ),
      );
}

// ── Conversation panel (compact messages) ────────────────────────────────

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({required this.state, required this.scrollCtrl});
  final ChatState state;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (state.messages.isEmpty) return const _CodeEmptyState();
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      itemCount: state.messages.length,
      itemBuilder: (_, i) => _CompactMessage(message: state.messages[i]),
    );
  }
}

/// Claude-Code-style flat transcript: no bubbles, just a left rail marker
/// plus the content flowing in the column.
class _CompactMessage extends StatelessWidget {
  const _CompactMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == 'tool') {
      return _ToolCallInline(message: message);
    }
    final isUser = message.role == 'user';
    final accent = isUser ? AppTheme.blue400 : AppTheme.blue300;
    final label = isUser ? '>' : '\u2726'; // ❯ user, ✦ assistant

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left rail marker (Claude Code uses a small caret/dot)
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: GoogleFonts.dmMono(
                  fontSize: 12,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: isUser
                ? SelectableText(
                    message.content,
                    style: GoogleFonts.sora(
                      fontSize: 13.5,
                      color: AppTheme.textHigh,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : (message.isStreaming && message.content.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: TypingIndicator(),
                      )
                    : MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.sora(
                              fontSize: 13.5,
                              color: AppTheme.textHigh,
                              height: 1.6),
                          code: GoogleFonts.dmMono(
                              fontSize: 12,
                              color: AppTheme.blue300,
                              backgroundColor:
                                  AppTheme.blue500.withValues(alpha: 0.08)),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    AppTheme.blue500.withValues(alpha: 0.12)),
                          ),
                          codeblockPadding: const EdgeInsets.all(12),
                          blockSpacing: 8,
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}

// ── Code output panel ─────────────────────────────────────────────────────

class _CodeOutputPanel extends StatelessWidget {
  const _CodeOutputPanel({
    required this.snippets,
    this.isLoading = false,
  });
  final List<_CodeSnippet> snippets;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (snippets.isEmpty) {
      return _NoCodePlaceholder(isLoading: isLoading);
    }
    final snippet = snippets.last;
    return Column(children: [
      if (snippets.length > 1)
        _SnippetTabs(
          snippets: snippets,
          selectedIndex: snippets.length - 1,
          onSelect: (_) {},
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
              bottom:
                  BorderSide(color: AppTheme.blue500.withValues(alpha: 0.1))),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: sel ? AppTheme.blue400 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(snippets[i].language,
                    style: GoogleFonts.dmMono(
                        fontSize: 11,
                        color: sel ? AppTheme.blue300 : AppTheme.textMid,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface2.withValues(alpha: 0.5),
            border: Border(
                bottom:
                    BorderSide(color: AppTheme.blue500.withValues(alpha: 0.1))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
                border:
                    Border.all(color: AppTheme.blue500.withValues(alpha: 0.3)),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppTheme.blue500.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isLoading ? Icons.hourglass_top_rounded : Icons.code_off_rounded,
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
            style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textLow),
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
              size: 12,
              color: _copied ? AppTheme.blue400 : AppTheme.textMid,
            ),
            const SizedBox(width: 5),
            Text(
              _copied ? 'Copied!' : 'Copy',
              style: GoogleFonts.sora(
                  fontSize: 11,
                  color: _copied ? AppTheme.blue400 : AppTheme.textMid,
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
                border:
                    Border.all(color: AppTheme.blue500.withValues(alpha: 0.3)),
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
                style: GoogleFonts.sora(fontSize: 13, color: AppTheme.textMid)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map((s) => GestureDetector(
                        onTap: () =>
                            ref.read(codeProvider.notifier).sendMessage(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppTheme.blue500.withValues(alpha: 0.15)),
                          ),
                          child: Text(s,
                              style: GoogleFonts.sora(
                                  fontSize: 12, color: AppTheme.textMid)),
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

  /// Splits the tool message into a header (first line, e.g. `$ ls -la`) and
  /// the body (everything else — the captured output).
  ({String header, String body}) _split(String raw) {
    final idx = raw.indexOf('\n');
    if (idx < 0) return (header: raw, body: '');
    return (header: raw.substring(0, idx), body: raw.substring(idx + 1));
  }

  IconData _iconFor(String header) {
    if (header.startsWith('\$')) return Icons.terminal_rounded;
    if (header.contains('write') || header.contains('edit')) {
      return Icons.edit_note_rounded;
    }
    if (header.contains('read')) return Icons.description_outlined;
    if (header.contains('ls')) return Icons.folder_open_rounded;
    if (header.contains('grep')) return Icons.search_rounded;
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final parts = _split(widget.message.content);
    final hasBody = parts.body.trim().isNotEmpty;
    final bodyLineCount = hasBody ? parts.body.trim().split('\n').length : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match _CompactMessage rail width so tool calls visually align
          // with assistant/user turns.
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(_iconFor(parts.header),
                  size: 12, color: AppTheme.blue400),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — always visible, click to toggle body
                  InkWell(
                    onTap: hasBody
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: SelectableText(
                            parts.header,
                            style: GoogleFonts.dmMono(
                                fontSize: 11.5,
                                color: AppTheme.blue300,
                                fontWeight: FontWeight.w500,
                                height: 1.4),
                            maxLines: 1,
                          ),
                        ),
                        if (hasBody) ...[
                          Text('$bodyLineCount lines',
                              style: GoogleFonts.dmMono(
                                  fontSize: 10, color: AppTheme.textLow)),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 12,
                            color: AppTheme.textLow,
                          ),
                        ],
                      ]),
                    ),
                  ),
                  // Body (output) — terminal-styled
                  if (hasBody && _expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                      child: SelectableText(
                        parts.body.trimRight(),
                        style: GoogleFonts.dmMono(
                            fontSize: 11,
                            color: AppTheme.textMid,
                            height: 1.45),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────

class _CodeSnippet {
  const _CodeSnippet({required this.language, required this.code});
  final String language;
  final String code;
}
