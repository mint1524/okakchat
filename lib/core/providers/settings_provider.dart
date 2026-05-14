import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings({
    this.language = 'en',
    this.sidebarOpen = true,
  });
  final String language;    // 'en' | 'ru'
  final bool sidebarOpen;

  AppSettings copyWith({String? language, bool? sidebarOpen}) => AppSettings(
        language: language ?? this.language,
        sidebarOpen: sidebarOpen ?? this.sidebarOpen,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setLanguage(String lang) =>
      state = state.copyWith(language: lang);

  void toggleSidebar() =>
      state = state.copyWith(sidebarOpen: !state.sidebarOpen);

  void setSidebarOpen(bool open) =>
      state = state.copyWith(sidebarOpen: open);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(() => SettingsNotifier());
