import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/api/api_client.dart';
import 'package:okakchat/core/api/chat_api.dart';

final _historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ChatApi(ref.watch(dioProvider));
  final list = await api.getConversations();
  return list.cast<Map<String, dynamic>>();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_historyProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_historyProvider),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No conversations yet'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    leading: Icon(_modeIcon(item['mode'] as String? ?? 'chat')),
                    title: Text(
                      item['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item['modelId']} · ${item['mode']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ChatApi(ref.read(dioProvider))
                            .deleteConversation(item['id'] as String);
                        ref.invalidate(_historyProvider);
                      },
                    ),
                    onTap: () => context.go('/chat/${item['id']}'),
                  );
                },
              ),
      ),
    );
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'coding' => Icons.code,
        'agent' => Icons.terminal,
        _ => Icons.chat_outlined,
      };
}
