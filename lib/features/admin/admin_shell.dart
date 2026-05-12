import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'user_list_screen.dart';
import 'audit_log_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null || !user.isAdmin) {
      return const Scaffold(
          body: Center(child: Text('Access denied')));
    }
    final screens = [const UserListScreen(), const AuditLogScreen()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor:
            Theme.of(context).colorScheme.errorContainer,
        foregroundColor:
            Theme.of(context).colorScheme.onErrorContainer,
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(
              icon: Icon(Icons.history_edu), label: 'Audit Log'),
        ],
      ),
    );
  }
}
