import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/router/router.dart';
import 'package:okakchat/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: OkakChatApp()));
}

class OkakChatApp extends ConsumerWidget {
  const OkakChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'OKAK Chat',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
