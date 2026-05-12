import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';
import 'message_bubble.dart';
import 'chat_input.dart';
import 'model_selector.dart';
import 'model_settings_sheet.dart';

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
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // Model dropdown — takes remaining space
        Expanded(
          child: ModelSelector(
            selectedModel: state.selectedModel,
            models: state.models,
            onSelected: (m) => ref.read(chatProvider.notifier).selectModel(m),
          ),
        ),
        const SizedBox(width: 8),
        // Chat / Code mode
        _ModeButton(
          label: 'Chat',
          icon: Icons.chat_bubble_outline_rounded,
          selected: state.mode == 'chat',
          onTap: () => ref.read(chatProvider.notifier).setMode('chat'),
        ),
        const SizedBox(width: 4),
        _ModeButton(
          label: 'Code',
          icon: Icons.code_rounded,
          selected: state.mode == 'coding',
          onTap: () => ref.read(chatProvider.notifier).setMode('coding'),
        ),
        const SizedBox(width: 4),
        // Settings
        _TopBarIconBtn(
          icon: Icons.tune_rounded,
          tooltip: 'Model settings',
          onTap: () => ModelSettingsSheet.show(context),
        ),
      ]),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            Icon(icon, size: 14,
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

class _TopBarIconBtn extends StatefulWidget {
  const _TopBarIconBtn(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  State<_TopBarIconBtn> createState() => _TopBarIconBtnState();
}
class _TopBarIconBtnState extends State<_TopBarIconBtn> {
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
              duration: const Duration(milliseconds: 140),
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.blue500.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 18, color: AppTheme.textMid),
            ),
          ),
        ),
      );
}

class _EmptyState extends StatefulWidget {
  const _EmptyState();
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blue500
                        .withValues(alpha: 0.12 + 0.12 * _pulse.value),
                    blurRadius: 30 + 20 * _pulse.value,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            ),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.blue900,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.blue500.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 36, color: AppTheme.blue400),
            ),
          ),
          const SizedBox(height: 24),
          Text('What can I help with?',
              style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHigh,
                  letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text('Choose a model above and start typing.',
              style: GoogleFonts.sora(
                  fontSize: 14, color: AppTheme.textMid)),
        ],
      ),
    );
  }
}
