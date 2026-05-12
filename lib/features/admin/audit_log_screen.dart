import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

final _auditProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ref.watch(dioProvider).get('/api/admin/audit');
  return res.data as List<dynamic>;
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(_auditProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final l = list[i] as Map<String, dynamic>;
          return ListTile(
            leading: const Icon(Icons.history_edu),
            title: Text(
                '${l['action']} → ${l['targetType']}:${l['targetId']}'),
            subtitle: Text(l['createdAt'] as String),
          );
        },
      ),
    );
  }
}
