import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';
import 'model_settings_sheet.dart';

// ── Skills definition ─────────────────────────────────────────────────────

class _Skill {
  const _Skill(this.name, this.description, this.template);
  final String name;
  final String description;
  final String template;
}

const _skills = [
  _Skill('/explain', 'Explain in simple terms', 'Explain in simple terms: '),
  _Skill('/summarize', 'Summarise the conversation', 'Summarise our conversation so far.'),
  _Skill('/refactor', 'Suggest code improvements', 'Refactor the following code for readability and performance:\n\n'),
  _Skill('/test', 'Write unit tests', 'Write comprehensive unit tests for:\n\n'),
  _Skill('/review', 'Code review', 'Do a thorough code review of the following:\n\n'),
  _Skill('/debug', 'Debug this issue', 'Help me debug this issue:\n\n'),
  _Skill('/docs', 'Generate documentation', 'Generate clear documentation for:\n\n'),
  _Skill('/translate', 'Translate text', 'Translate the following to '),
  _Skill('/diagram', 'Create a diagram', 'Create a mermaid diagram showing: '),
  _Skill('/plan', 'Plan implementation', 'Create a step-by-step implementation plan for:\n\n'),
  _Skill('/optimize', 'Optimize performance', 'Optimize the following for performance:\n\n'),
  _Skill('/security', 'Security review', 'Review the following for security vulnerabilities:\n\n'),
];

// ── Main input widget ─────────────────────────────────────────────────────

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({
    super.key,
    this.onSend,
    this.tools,
    required this.provider,
  });
  final VoidCallback? onSend;
  final List<Map<String, dynamic>>? tools;
  final StateNotifierProvider<ChatNotifier, ChatState> provider;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  List<_Skill> _skillSuggestions = [];

  late final AnimationController _sendCtrl;
  late final Animation<double> _sendScale;

  @override
  void initState() {
    super.initState();
    _sendCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _sendScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _sendCtrl, curve: Curves.easeOutBack));

    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
      if (has) _sendCtrl.forward(); else _sendCtrl.reverse();
    }
    // Slash skill suggestions
    final text = _ctrl.text;
    if (text.startsWith('/') && !text.contains(' ')) {
      final query = text.toLowerCase();
      final matches = _skills
          .where((s) => s.name.startsWith(query))
          .toList();
      if (matches != _skillSuggestions) {
        setState(() => _skillSuggestions = matches);
      }
    } else if (_skillSuggestions.isNotEmpty) {
      setState(() => _skillSuggestions = []);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _sendCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _skillSuggestions = []);
    ref.read(widget.provider.notifier).sendMessage(text,
        tools: widget.tools);
    widget.onSend?.call();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) {
        ref.read(widget.provider.notifier).addAttachedFile(f.path!);
      } else if (f.name.isNotEmpty) {
        ref.read(widget.provider.notifier).addAttachedFile(f.name);
      }
    }
  }

  void _applySkill(_Skill skill) {
    _ctrl.text = skill.template;
    _ctrl.selection =
        TextSelection.collapsed(offset: skill.template.length);
    setState(() => _skillSuggestions = []);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final isLoading = state.isLoading;
    final attachedFiles = state.attachedFiles;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Skill suggestions ────────────────────────────────────────
          if (_skillSuggestions.isNotEmpty)
            _SkillSuggestions(
              skills: _skillSuggestions,
              onSelect: _applySkill,
            ),

          // ── Attached files ────────────────────────────────────────────
          if (attachedFiles.isNotEmpty)
            _AttachedFilesRow(
              files: attachedFiles,
              onRemove: (f) =>
                  ref.read(widget.provider.notifier).removeAttachedFile(f),
            ),

          // ── Input row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach file button
                _AttachBtn(onTap: _pickFile),
                const SizedBox(width: 8),
                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: AppTheme.surface1,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? AppTheme.blue500.withValues(alpha: 0.45)
                            : AppTheme.blue500.withValues(alpha: 0.15),
                        width: _focusNode.hasFocus ? 1.5 : 1,
                      ),
                    ),
                    child: Focus(
                      onFocusChange: (_) => setState(() {}),
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey ==
                                LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isMetaPressed &&
                            !HardwareKeyboard.instance.isControlPressed &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _submit();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        maxLines: null,
                        style: GoogleFonts.sora(
                            fontSize: 14,
                            color: AppTheme.textHigh,
                            height: 1.5),
                        cursorColor: AppTheme.blue400,
                        decoration: InputDecoration(
                          hintText: 'Message… (/ for skills)',
                          hintStyle: GoogleFonts.sora(
                              fontSize: 14,
                              color: AppTheme.textLow),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send / Stop
                SizedBox(
                  width: 44,
                  height: 44,
                  child: isLoading
                      ? _StopButton(
                          onTap: () {
                            ref.read(widget.provider.notifier).cancel();
                            ref.read(wsClientProvider).cancel();
                          },
                        )
                      : ScaleTransition(
                          scale: _sendScale,
                          child: _SendButton(
                            active: _hasText,
                            onTap: _hasText ? _submit : null,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ── Bottom bar: model, context, settings ─────────────────────
          _BottomBar(provider: widget.provider),
        ],
      ),
    );
  }
}

// ── Bottom bar (model selector + context + settings) ──────────────────────

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.provider});
  final StateNotifierProvider<ChatNotifier, ChatState> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final fill = state.contextFillFraction;
    final used = state.estimatedTokensUsed;
    final max = state.maxTokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(children: [
        // Model selector
        Expanded(
          child: _ModelDropdown(
            selectedModel: state.selectedModel,
            models: state.models,
            onSelected: notifier.selectModel,
          ),
        ),
        const SizedBox(width: 8),
        // Context window indicator
        GestureDetector(
          onTap: () => _showContextInfo(context, used, max, fill),
          child: _ContextChip(fill: fill, used: used, max: max),
        ),
        const SizedBox(width: 6),
        // Settings button
        GestureDetector(
          onTap: () => ModelSettingsSheet.show(context, provider: provider),
          child: Container(
            height: 28,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune_rounded,
                  size: 13, color: AppTheme.textMid),
              const SizedBox(width: 4),
              Text('Settings',
                  style: GoogleFonts.sora(
                      fontSize: 11, color: AppTheme.textMid)),
            ]),
          ),
        ),
      ]),
    );
  }

  void _showContextInfo(
      BuildContext ctx, int used, int max, double fill) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _ContextInfoDialog(used: used, max: max, fill: fill),
    );
  }
}

class _ContextInfoDialog extends StatelessWidget {
  const _ContextInfoDialog(
      {required this.used, required this.max, required this.fill});
  final int used;
  final int max;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final pct = (fill * 100).round();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface2.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Context window',
                  style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textHigh)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fill,
                  backgroundColor: AppTheme.surface1,
                  valueColor: AlwaysStoppedAnimation(
                    fill > 0.8
                        ? const Color(0xFFEF4444)
                        : fill > 0.6
                            ? const Color(0xFFF59E0B)
                            : AppTheme.blue400,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('~$used tokens used',
                      style: GoogleFonts.sora(
                          fontSize: 13, color: AppTheme.textMid)),
                  Text('$max max',
                      style: GoogleFonts.sora(
                          fontSize: 13, color: AppTheme.textMid)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$pct% of context window used',
                style: GoogleFonts.sora(
                    fontSize: 12, color: AppTheme.textLow),
              ),
              if (fill > 0.85) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Context is nearly full. Start a new chat to avoid truncation.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                        fontSize: 12,
                        color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip(
      {required this.fill, required this.used, required this.max});
  final double fill;
  final int used;
  final int max;

  Color get _color => fill > 0.8
      ? const Color(0xFFEF4444)
      : fill > 0.6
          ? const Color(0xFFF59E0B)
          : AppTheme.textMid;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fill,
                backgroundColor: AppTheme.surface1,
                valueColor: AlwaysStoppedAnimation(_color),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${(fill * 100).round()}%',
            style: GoogleFonts.sora(
                fontSize: 11, color: _color),
          ),
        ]),
      );
}

class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.selectedModel,
    required this.models,
    required this.onSelected,
  });
  final String selectedModel;
  final List<Map<String, dynamic>> models;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();
    final validId = models.any((m) => m['id'] == selectedModel)
        ? selectedModel
        : models.first['id'] as String;
    final selected = models.firstWhere((m) => m['id'] == validId);

    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.blue500.withValues(alpha: 0.2)),
      ),
      itemBuilder: (_) => models.map((m) {
        final id = m['id'] as String;
        final name = m['displayName'] as String;
        final isSel = id == validId;
        return PopupMenuItem<String>(
          value: id,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(children: [
            if (isSel)
              Icon(Icons.check_rounded,
                  size: 14, color: AppTheme.blue400)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 8),
            Text(name,
                style: GoogleFonts.sora(
                    fontSize: 13,
                    color: isSel
                        ? AppTheme.blue300
                        : AppTheme.textHigh,
                    fontWeight: isSel
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ]),
        );
      }).toList(),
      child: Container(
        height: 28,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.psychology_rounded,
              size: 13, color: AppTheme.blue400),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              selected['displayName'] as String,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  color: AppTheme.textHigh,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 13, color: AppTheme.textMid),
        ]),
      ),
    );
  }
}

// ── Skill suggestions overlay ─────────────────────────────────────────────

class _SkillSuggestions extends StatelessWidget {
  const _SkillSuggestions(
      {required this.skills, required this.onSelect});
  final List<_Skill> skills;
  final void Function(_Skill) onSelect;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: skills.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return GestureDetector(
              onTap: () => onSelect(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0
                        ? const Radius.circular(12)
                        : Radius.zero,
                    bottom: i == skills.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.blue500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(s.name,
                        style: GoogleFonts.dmMono(
                            fontSize: 12,
                            color: AppTheme.blue300,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Text(s.description,
                      style: GoogleFonts.sora(
                          fontSize: 12, color: AppTheme.textMid)),
                ]),
              ),
            );
          }).toList(),
        ),
      );
}

// ── Attached files row ────────────────────────────────────────────────────

class _AttachedFilesRow extends StatelessWidget {
  const _AttachedFilesRow(
      {required this.files, required this.onRemove});
  final List<String> files;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final name = files[i].split('/').last;
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.attach_file_rounded,
                    size: 13, color: AppTheme.blue400),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                        fontSize: 11, color: AppTheme.textHigh),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => onRemove(files[i]),
                  child: Icon(Icons.close_rounded,
                      size: 12, color: AppTheme.textMid),
                ),
              ]),
            );
          },
        ),
      );
}

// ── Attach button ─────────────────────────────────────────────────────────

class _AttachBtn extends StatefulWidget {
  const _AttachBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AttachBtn> createState() => _AttachBtnState();
}

class _AttachBtnState extends State<_AttachBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.blue500.withValues(alpha: 0.1)
                  : AppTheme.surface1,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.blue500.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.attach_file_rounded,
                size: 18, color: AppTheme.textMid),
          ),
        ),
      );
}

// ── Send button ───────────────────────────────────────────────────────────

class _SendButton extends StatefulWidget {
  const _SendButton({required this.active, this.onTap});
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.active ? AppTheme.blue500 : AppTheme.surface3,
              borderRadius: BorderRadius.circular(12),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: AppTheme.blue500.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 20,
              color: widget.active ? Colors.white : AppTheme.textLow,
            ),
          ),
        ),
      );
}

// ── Stop button ───────────────────────────────────────────────────────────

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.stop_rounded,
              size: 20, color: AppTheme.textMid),
        ),
      );
}
