import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'chat_provider.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key, this.onSend, this.tools});
  final VoidCallback? onSend;
  final List<Map<String, dynamic>>? tools;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
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
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PlatformUtils.isIOS
                  ? CupertinoTextField(
                      controller: _ctrl,
                      placeholder: 'Message…',
                      minLines: 1,
                      maxLines: 6,
                      padding: const EdgeInsets.all(10),
                    )
                  : TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                    ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? IconButton(
                    onPressed: () => ref.read(wsClientProvider).cancel(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'Stop',
                  )
                : IconButton.filled(
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                  ),
          ],
        ),
      ),
    );
  }
}
