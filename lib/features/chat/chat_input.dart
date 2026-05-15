import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';
import 'model_picker.dart';
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
  _Skill('/summarize', 'Summarise the conversation',
      'Summarise our conversation so far.'),
  _Skill('/refactor', 'Suggest code improvements',
      'Refactor the following code for readability and performance:\n\n'),
  _Skill(
      '/test', 'Write unit tests', 'Write comprehensive unit tests for:\n\n'),
  _Skill('/review', 'Code review',
      'Do a thorough code review of the following:\n\n'),
  _Skill('/debug', 'Debug this issue', 'Help me debug this issue:\n\n'),
  _Skill('/docs', 'Generate documentation',
      'Generate clear documentation for:\n\n'),
  _Skill('/translate', 'Translate text', 'Translate the following to '),
  _Skill('/diagram', 'Create a diagram', 'Create a mermaid diagram showing: '),
  _Skill('/plan', 'Plan implementation',
      'Create a step-by-step implementation plan for:\n\n'),
  _Skill('/optimize', 'Optimize performance',
      'Optimize the following for performance:\n\n'),
  _Skill('/security', 'Security review',
      'Review the following for security vulnerabilities:\n\n'),
  _Skill('/arch', 'Architecture design', 'Design the architecture for:\n\n'),
  _Skill('/api', 'Design an API', 'Design a REST/GraphQL API for:\n\n'),
  _Skill('/db', 'Database schema', 'Design a database schema for:\n\n'),
  _Skill('/deploy', 'Deployment config',
      'Create deployment configuration for:\n\n'),
  _Skill('/ci', 'CI/CD pipeline',
      'Create a CI/CD pipeline configuration for:\n\n'),
  _Skill('/fix', 'Fix this error', 'Fix the following error:\n\n'),
  _Skill('/pr', 'Write PR description',
      'Write a clear pull request description for:\n\n'),
  _Skill('/commit', 'Write commit message',
      'Write a descriptive commit message for:\n\n'),
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
    _sendScale = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _sendCtrl, curve: Curves.easeOutBack));

    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    AppLogger.text('"${AppLogger.trunc(_ctrl.text, 60)}"  (len=${_ctrl.text.length})');
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
      if (has) {
        _sendCtrl.forward();
      } else {
        _sendCtrl.reverse();
      }
    }
    // Slash skill suggestions
    final text = _ctrl.text;
    if (text.startsWith('/') && !text.contains(' ')) {
      final query = text.toLowerCase();
      final matches = _skills.where((s) => s.name.startsWith(query)).toList();
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
    AppLogger.tap('Send — "${AppLogger.trunc(text, 80)}"');
    _ctrl.clear();
    setState(() => _skillSuggestions = []);
    ref.read(widget.provider.notifier).sendMessage(text, tools: widget.tools);
    widget.onSend?.call();
  }

  Future<void> _pickFile() async {
    AppLogger.tap('Attach — file picker opened');
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) {
      AppLogger.tap('Attach — cancelled');
      return;
    }
    for (final f in result.files) {
      final path = f.path ?? f.name;
      AppLogger.tap('Attach — file selected: $path');
      if (f.path != null) {
        ref.read(widget.provider.notifier).addAttachedFile(f.path!);
      } else if (f.name.isNotEmpty) {
        ref.read(widget.provider.notifier).addAttachedFile(f.name);
      }
    }
  }

  void _applySkill(_Skill skill) {
    AppLogger.tap('Skill selected: ${skill.name}');
    _ctrl.text = skill.template;
    _ctrl.selection = TextSelection.collapsed(offset: skill.template.length);
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
                // Text field with embedded attach button
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
                          child: _AttachBtn(onTap: _pickFile),
                        ),
                        Expanded(
                          child: Focus(
                            onFocusChange: (_) => setState(() {}),
                            onKeyEvent: (_, event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter &&
                                  !HardwareKeyboard.instance.isMetaPressed &&
                                  !HardwareKeyboard.instance.isControlPressed &&
                                  !HardwareKeyboard.instance.isShiftPressed) {
                                AppLogger.key('Enter → submit (no modifier)');
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
                                    fontSize: 14, color: AppTheme.textLow),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Send / Stop
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: isLoading
                                ? _StopButton(
                                    onTap: () {
                                      AppLogger.tap('Stop (input bar)');
                                      ref
                                          .read(widget.provider.notifier)
                                          .cancel();
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
                        ),
                      ],
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
    final limit = state.contextLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(children: [
        // Model selector (nikita design: company tabs + variants)
        ModelPickerButton(
          selectedModel: state.selectedModel,
          models: state.models,
          onSelected: notifier.selectModel,
        ),
        const SizedBox(width: 8),
        // Context window indicator
        GestureDetector(
          onTap: () => _showContextInfo(context, used, limit, fill),
          child: _ContextChip(fill: fill, used: used, max: limit),
        ),
        const SizedBox(width: 6),
        // Settings button
        GestureDetector(
          onTap: () => ModelSettingsSheet.show(context, provider: provider),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune_rounded, size: 11, color: AppTheme.textLow),
            const SizedBox(width: 3),
            Text('Settings',
                style: GoogleFonts.sora(fontSize: 10, color: AppTheme.textLow)),
          ]),
        ),
      ]),
    );
  }

  void _showContextInfo(BuildContext ctx, int used, int max, double fill) {
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
              border:
                  Border.all(color: AppTheme.blue500.withValues(alpha: 0.2)),
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
                style: GoogleFonts.sora(fontSize: 12, color: AppTheme.textLow),
              ),
              if (fill > 0.85) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Context is nearly full. Start a new chat to avoid truncation.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                        fontSize: 12, color: const Color(0xFFEF4444)),
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
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
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
          style: GoogleFonts.sora(fontSize: 11, color: _color),
        ),
      ]);
}

// ── Skill suggestions overlay ─────────────────────────────────────────────

class _SkillSuggestions extends StatelessWidget {
  const _SkillSuggestions({required this.skills, required this.onSelect});
  final List<_Skill> skills;
  final void Function(_Skill) onSelect;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.2)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: i == skills.length - 1
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
  const _AttachedFilesRow({required this.files, required this.onRemove});
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
            final path = files[i];
            final name = _attachmentName(path);
            return GestureDetector(
              onTap: () => _showAttachmentPreview(context, path),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.blue500.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _AttachmentThumb(path: path),
                  const SizedBox(width: 6),
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
                    onTap: () => onRemove(path),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: AppTheme.textMid),
                  ),
                ]),
              ),
            );
          },
        ),
      );
}

const _textAttachmentExts = {
  'txt',
  'md',
  'dart',
  'js',
  'ts',
  'tsx',
  'jsx',
  'py',
  'rb',
  'go',
  'rs',
  'swift',
  'kt',
  'java',
  'c',
  'cpp',
  'h',
  'hpp',
  'cs',
  'json',
  'yaml',
  'yml',
  'toml',
  'xml',
  'html',
  'css',
  'sh',
  'bash',
  'zsh',
  'sql',
};

const _imageAttachmentExts = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
};

String _attachmentName(String path) => path.split(RegExp(r'[/\\]')).last;

String _attachmentExt(String path) {
  final name = _attachmentName(path);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

bool _isImageAttachment(String path) =>
    _imageAttachmentExts.contains(_attachmentExt(path));

bool _isTextAttachment(String path) =>
    _textAttachmentExts.contains(_attachmentExt(path));

bool _localFileExists(String path) {
  if (kIsWeb) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<String> _readTextPreview(String path) async {
  final bytes = await File(path).readAsBytes();
  final previewBytes = bytes.length > 16000 ? bytes.sublist(0, 16000) : bytes;
  final text = utf8.decode(previewBytes, allowMalformed: true);
  return bytes.length > previewBytes.length
      ? '$text\n\n… truncated preview …'
      : text;
}

Future<void> _openExternally(String path) async {
  if (kIsWeb || !_localFileExists(path)) return;
  if (Platform.isMacOS) {
    await Process.start('open', [path]);
  } else if (Platform.isWindows) {
    await Process.start('cmd', ['/c', 'start', '', path], runInShell: true);
  } else {
    await Process.start('xdg-open', [path]);
  }
}

void _showAttachmentPreview(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    builder: (_) => _AttachmentPreviewDialog(path: path),
  );
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (_isImageAttachment(path) && _localFileExists(path)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined,
              size: 14, color: AppTheme.blue400),
        ),
      );
    }
    final icon = _isTextAttachment(path)
        ? Icons.description_outlined
        : Icons.attach_file_rounded;
    return Icon(icon, size: 14, color: AppTheme.blue400);
  }
}

class _AttachmentPreviewDialog extends StatelessWidget {
  const _AttachmentPreviewDialog({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final name = _attachmentName(path);
    final exists = _localFileExists(path);
    Widget body;

    if (_isImageAttachment(path) && exists) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Failed to load image'),
        ),
      );
    } else if (_isTextAttachment(path) && exists) {
      body = FutureBuilder<String>(
        future: _readTextPreview(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Text('Failed to read file: ${snapshot.error}');
          }
          return Container(
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                snapshot.data ?? '',
                style: GoogleFonts.dmMono(
                    fontSize: 12, height: 1.45, color: AppTheme.textHigh),
              ),
            ),
          );
        },
      );
    } else {
      body = Text(
        exists
            ? 'Preview is not available for this file type.'
            : 'Only the file name is available for this attachment.',
        style: GoogleFonts.sora(fontSize: 13, color: AppTheme.textMid),
      );
    }

    return AlertDialog(
      backgroundColor: AppTheme.surface1,
      title: Text(name,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textHigh)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (exists)
          FilledButton.icon(
            onPressed: () => _openExternally(path),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open externally'),
          ),
      ],
    );
  }
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
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.blue500.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.attach_file_rounded,
                size: 17,
                color: _hovered ? AppTheme.blue400 : AppTheme.textLow),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.active ? AppTheme.blue500 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 18,
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.blue500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.stop_rounded, size: 16, color: AppTheme.blue400),
        ),
      );
}
