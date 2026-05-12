import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key, this.onSend, this.tools});
  final VoidCallback? onSend;
  final List<Map<String, dynamic>>? tools;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  late final AnimationController _sendCtrl;
  late final Animation<double> _sendScale;

  @override
  void initState() {
    super.initState();
    _sendCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _sendScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _sendCtrl, curve: Curves.easeOutBack));
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
        if (has) _sendCtrl.forward();
        else _sendCtrl.reverse();
      }
    });
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
    ref.read(chatProvider.notifier).sendMessage(text, tools: widget.tools);
    widget.onSend?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(chatProvider).isLoading;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
                  // Cmd/Ctrl+Enter = newline, plain Enter = send
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
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
                        fontSize: 14, color: AppTheme.textHigh, height: 1.5),
                    cursorColor: AppTheme.blue400,
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: GoogleFonts.sora(
                          fontSize: 14, color: AppTheme.textLow),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send / Stop button
            SizedBox(
              width: 44, height: 44,
              child: isLoading
                  ? _StopButton(onTap: () => ref.read(wsClientProvider).cancel())
                  : ScaleTransition(
                      scale: _sendScale,
                      child: _SendButton(
                          active: _hasText, onTap: _hasText ? _submit : null),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? 0.88 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: widget.active ? AppTheme.blue500 : AppTheme.surface3,
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.active
              ? [BoxShadow(
                  color: AppTheme.blue500.withValues(alpha: 0.4),
                  blurRadius: 14, spreadRadius: -2,
                  offset: const Offset(0, 3))]
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

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.blue500.withValues(alpha: 0.25)),
      ),
      child: const Icon(Icons.stop_rounded, size: 20, color: AppTheme.textMid),
    ),
  );
}
