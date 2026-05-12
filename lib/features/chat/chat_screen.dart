import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'chat_input.dart';
import 'model_selector.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.agentMode = false, this.workspacePath});
  final String? conversationId;
  final bool agentMode;
  final String? workspacePath;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(chatProvider.notifier).loadModels();
        if (widget.conversationId != null) {
          await ref
              .read(chatProvider.notifier)
              .loadConversation(widget.conversationId!);
        }
      } catch (_) {
        // Auth not ready yet — router will redirect to login
      }
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Column(children: [
      // Top bar
      _TopBar(state: state),
      const Divider(height: 1),
      // Messages
      Expanded(
        child: state.messages.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: state.messages.length,
                itemBuilder: (_, i) =>
                    MessageBubble(message: state.messages[i]),
              ),
      ),
      const Divider(height: 1),
      ChatInput(onSend: _scrollToBottom),
    ]);
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state});
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          child: ModelSelector(
            selectedModel: state.selectedModel,
            models: state.models,
            onSelected: (m) => ref.read(chatProvider.notifier).selectModel(m),
          ),
        ),
        // Mode selector
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'chat', icon: Icon(Icons.chat_outlined, size: 16), label: Text('Chat')),
            ButtonSegment(value: 'coding', icon: Icon(Icons.code, size: 16), label: Text('Code')),
          ],
          selected: {state.mode == 'agent' ? 'chat' : state.mode},
          onSelectionChanged: (s) =>
              ref.read(chatProvider.notifier).setMode(s.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_comment_outlined),
          onPressed: () => ref.read(chatProvider.notifier).newChat(),
          tooltip: 'New chat',
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 36, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'What can I help with?',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a model above and start typing.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
