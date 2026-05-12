import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'chat_provider.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';

    if (isTool) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(
          message.content,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUser
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
          ),
          child: isUser
              ? Text(
                  message.content,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary),
                )
              : MarkdownBody(
                  data: message.isStreaming
                      ? '${message.content}▊'
                      : message.content,
                  builders: {'code': _CodeBuilder()},
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    code: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final language =
        element.attributes['class']?.replaceFirst('language-', '') ??
            'plaintext';
    return Stack(children: [
      HighlightView(
        code,
        language: language,
        theme: atomOneDarkTheme,
        padding: const EdgeInsets.all(12),
        textStyle:
            const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      Positioned(
        right: 4,
        top: 4,
        child: IconButton(
          icon: const Icon(Icons.copy, size: 16, color: Colors.white60),
          onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          tooltip: 'Copy',
        ),
      ),
    ]);
  }
}
