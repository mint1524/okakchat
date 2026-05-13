import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'user_list_screen.dart' show AdminError;

final _auditProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ref.watch(dioProvider).get('/api/admin/audit');
  return res.data as List<dynamic>;
});

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(_auditProvider);
    return logs.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.blue400),
      ),
      error: (e, _) => AdminError(
        message: e.toString(),
        onRetry: () => ref.invalidate(_auditProvider),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Text('No audit logs yet',
                  style: GoogleFonts.sora(color: AppTheme.textMid)),
            )
          : ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final l = list[i] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.history_edu_rounded,
                      color: AppTheme.blue400, size: 20),
                  title: Text(
                    '${l['action']} → ${l['targetType']}:${l['targetId']}',
                    style: GoogleFonts.sora(
                        fontSize: 13, color: AppTheme.textHigh),
                  ),
                  subtitle: Text(l['createdAt'] as String? ?? '',
                      style: GoogleFonts.sora(
                          fontSize: 11, color: AppTheme.textMid)),
                );
              },
            ),
    );
  }
}
