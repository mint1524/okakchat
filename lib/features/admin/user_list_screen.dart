import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'user_detail_screen.dart';

final _usersProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ref.watch(dioProvider).get('/api/admin/users');
  return res.data as List<dynamic>;
});

class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_usersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final u = list[i] as Map<String, dynamic>;
          final name = u['displayName'] as String;
          return ListTile(
            leading: CircleAvatar(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
            title: Text(name),
            subtitle: Text(u['email'] as String),
            trailing: Icon(
              u['emailVerified'] == true
                  ? Icons.verified
                  : Icons.warning_amber,
              color: u['emailVerified'] == true
                  ? Colors.green
                  : Colors.orange,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserDetailScreen(
                  userId: u['id'] as String,
                  email: u['email'] as String,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
