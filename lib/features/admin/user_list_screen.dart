import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'user_detail_screen.dart';

final _usersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ref.watch(dioProvider).get('/api/admin/users');
  return res.data as List<dynamic>;
});

class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_usersProvider);
    return users.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.blue400),
      ),
      error: (e, _) => AdminError(
        message: e.toString(),
        onRetry: () => ref.invalidate(_usersProvider),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Text('No users found',
                  style: GoogleFonts.sora(color: AppTheme.textMid)),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final u = list[i] as Map<String, dynamic>;
                final name = (u['displayName'] as String?) ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.blue900,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.sora(
                          color: AppTheme.blue300, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(name,
                      style: GoogleFonts.sora(
                          fontSize: 14, color: AppTheme.textHigh)),
                  subtitle: Text(u['email'] as String? ?? '',
                      style: GoogleFonts.sora(
                          fontSize: 12, color: AppTheme.textMid)),
                  trailing: Icon(
                    u['emailVerified'] == true
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: u['emailVerified'] == true
                        ? AppTheme.blue400
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

class AdminError extends StatelessWidget {
  const AdminError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 40, color: AppTheme.textMid),
            const SizedBox(height: 16),
            Text('Failed to load',
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textHigh)),
            const SizedBox(height: 8),
            Text(
              _friendlyError(message),
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 13, color: AppTheme.textMid),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Try again', style: GoogleFonts.sora(fontSize: 13)),
            ),
          ]),
        ),
      );

  String _friendlyError(String raw) {
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'Session expired. Try again — the app will refresh your session automatically.';
    }
    if (raw.contains('403') || raw.contains('Forbidden')) {
      return 'Access denied. Admin privileges required.';
    }
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'Cannot reach the server. Check your network connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
