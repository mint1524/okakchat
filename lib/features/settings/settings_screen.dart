import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/auth/login');
            },
          ),
        ],
      ),
    );
  }
}
