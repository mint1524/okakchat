/// Simple two-language string table (en / ru).
/// Usage: S.of(context).newChat  OR  S.current.newChat
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class S {
  const S._(this._lang);
  final String _lang;

  static S of(BuildContext context) {
    // Resolved through InheritedWidget injected in MaterialApp.builder
    return _SScope.of(context);
  }

  static S current = const S._('en');

  // ── Navigation ─────────────────────────────────────────────────────────
  String get chat         => _('Chat', 'Чат');
  String get code         => _('Code', 'Код');
  String get history      => _('History', 'История');
  String get settings     => _('Settings', 'Настройки');
  String get admin        => _('Admin', 'Админ');
  String get newChat      => _('New chat', 'Новый чат');
  String get newSession   => _('New session', 'Новая сессия');

  // ── Chat ───────────────────────────────────────────────────────────────
  String get messagePlaceholder   => _('Message…', 'Сообщение…');
  String get sendMessage          => _('Send', 'Отправить');
  String get stopGeneration       => _('Stop', 'Стоп');
  String get whatCanIHelpWith     => _('What can I help with?', 'Чем могу помочь?');
  String get chooseModelAndType   => _('Choose a model and start typing.', 'Выберите модель и начните вводить.');
  String get codeAssistant        => _('Code assistant', 'Ассистент кода');
  String get askToWriteCode       => _('Ask Claude to write, review, or explain code.', 'Попросите Claude написать, проверить или объяснить код.');
  String get noCodeYet            => _('No code yet', 'Кода ещё нет');
  String get waitingForCode       => _('Ask Claude to write code.\nCode blocks will appear here.', 'Попросите Claude написать код.\nБлоки кода появятся здесь.');
  String get generating           => _('Generating…', 'Генерация…');
  String get copy                 => _('Copy', 'Копировать');
  String get copied               => _('Copied!', 'Скопировано!');
  String get copyMessage          => _('Copy message', 'Скопировать сообщение');
  String get edit                 => _('Edit', 'Редактировать');
  String get regenerate           => _('Regenerate', 'Регенерировать');
  String get attachFile           => _('Attach file', 'Прикрепить файл');
  String get toolOutput           => _('Tool output', 'Вывод инструмента');
  String get contextWindow        => _('Context window', 'Контекстное окно');
  String get tokens               => _('tokens', 'токенов');
  String get used                 => _('used', 'использовано');
  String get searchMessages       => _('Search chats…', 'Поиск чатов…');

  // ── Models / Settings ──────────────────────────────────────────────────
  String get modelSettings        => _('Model settings', 'Настройки модели');
  String get done                 => _('Done', 'Готово');
  String get style                => _('Style', 'Стиль');
  String get responseLength       => _('Response length', 'Длина ответа');
  String get systemPrompt         => _('System prompt', 'Системный промпт');
  String get resetToDefaults      => _('Reset to defaults', 'Сброс настроек');
  String get balanced             => _('Balanced', 'Сбалансированный');
  String get precise              => _('Precise', 'Точный');
  String get creative             => _('Creative', 'Творческий');
  String get coding               => _('Coding', 'Программирование');
  String get concise              => _('Concise', 'Кратко');
  String get normal               => _('Normal', 'Обычный');
  String get detailed             => _('Detailed', 'Детально');
  String get extended             => _('Extended', 'Развёрнуто');
  String get reasoning            => _('Reasoning', 'Рассуждение');
  String get planMode             => _('Plan', 'Планирование');
  String get askBeforeChanges     => _('Ask first', 'Спрашивать');
  String get fullChanges          => _('Full edit', 'Полное редактирование');
  String get mode                 => _('Mode', 'Режим');

  // ── Code mode settings ─────────────────────────────────────────────────
  String get allowFileEdits       => _('Allow file edits', 'Разрешить правку файлов');
  String get allowCommands        => _('Allow commands', 'Разрешить команды');
  String get allowNetworkAccess   => _('Allow network access', 'Разрешить сеть');
  String get workspacePath        => _('Workspace path', 'Путь к рабочей папке');

  // ── Skills ─────────────────────────────────────────────────────────────
  String get skills               => _('Skills', 'Навыки');
  String get skillsHint           => _('Type / to use a skill', 'Введите / чтобы использовать навык');

  // ── Profile / Auth ─────────────────────────────────────────────────────
  String get profile              => _('Profile', 'Профиль');
  String get signOut              => _('Sign out', 'Выйти');
  String get signIn               => _('Sign in', 'Войти');
  String get register             => _('Register', 'Зарегистрироваться');
  String get language             => _('Language', 'Язык');
  String get theme                => _('Theme', 'Тема');
  String get close                => _('Close', 'Закрыть');
  String get cancel               => _('Cancel', 'Отмена');

  // ── Errors ─────────────────────────────────────────────────────────────
  String get errorApiUnavailable  => _('AI service unavailable. Check your connection.', 'Сервис ИИ недоступен. Проверьте соединение.');
  String get errorUnauthorized    => _('Session expired. Please sign in again.', 'Сессия истекла. Войдите снова.');
  String get errorNetworkFailed   => _('Network error. Retrying…', 'Ошибка сети. Повтор…');
  String get errorUnknown         => _('Something went wrong. Please try again.', 'Что-то пошло не так. Попробуйте снова.');
  String get retry                => _('Retry', 'Повторить');
  String get dismiss              => _('Dismiss', 'Закрыть');

  // ── Misc ───────────────────────────────────────────────────────────────
  String get today                => _('Today', 'Сегодня');
  String get yesterday            => _('Yesterday', 'Вчера');
  String get justNow              => _('Just now', 'Только что');

  String _(String en, String ru) => _lang == 'ru' ? ru : en;
}

// ── InheritedWidget bridge ────────────────────────────────────────────────

class _SScope extends InheritedWidget {
  const _SScope({required this.s, required super.child});
  final S s;

  static S of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SScope>();
    return scope?.s ?? S.current;
  }

  @override
  bool updateShouldNotify(_SScope old) => old.s._lang != s._lang;
}

/// Wrap your widget tree with this to inject [S].
class ScopeProvider extends ConsumerWidget {
  const ScopeProvider({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final s = S._(lang);
    S.current = s;
    return _SScope(s: s, child: child);
  }
}
