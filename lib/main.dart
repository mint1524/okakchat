import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/l10n/strings.dart';
import 'package:okakchat/core/router/router.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom window frame on desktop (macOS / Windows / Linux)
  if (!kIsWeb && PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1100, 720),
        minimumSize: Size(800, 560),
        center: true,
        titleBarStyle: TitleBarStyle.hidden, // removes native title bar
        windowButtonVisibility: false,       // hides traffic-light buttons
        backgroundColor: Colors.transparent,
        title: 'OKAK Chat',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const ProviderScope(child: OkakChatApp()));
}

class OkakChatApp extends ConsumerWidget {
  const OkakChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'OKAK Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark, // always dark for high-tech look
      routerConfig: router,
      builder: (context, child) => ScopeProvider(child: child ?? const SizedBox.shrink()),
    );
  }
}
