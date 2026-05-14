# OKAK Chat Recovery Checkpoint

Use this file as the only recovery context for the current Flutter task.

## File discovery

Use only files returned by `rg --files` or `ls`. Do not invent paths.

## Workspace

Work in:

```text
/Users/min7t/OKAK APP v3/okakchat
```

Do not work from `okakchatbackend` for this Flutter task.

## Dirty files to continue from

These files currently contain in-progress user-approved work. Do not revert them:

```text
lib/core/api/ws_client.dart
lib/features/chat/chat_input.dart
lib/features/chat/chat_provider.dart
lib/features/chat/chat_screen.dart
lib/features/chat/code_screen.dart
lib/features/chat/message_bubble.dart
lib/features/chat/model_settings_sheet.dart
lib/features/shell/sidebar.dart
lib/core/l10n/
lib/core/providers/
lib/core/widgets/notification_banner.dart
```

## Recovery rules

1. Start with `git status --short`.
2. Read files in small chunks with `sed -n`, not huge parallel Bash batches.
3. Use exact real paths:
   - `lib/features/shell/sidebar.dart`
   - the shell wrapper file returned by `ls lib/features/shell/*_shell.dart`
   - `lib/features/chat/chat_provider.dart`
   - `lib/features/chat/chat_screen.dart`
   - `lib/features/chat/code_screen.dart`
4. Do not ask what to do with `model_settings_sheet.dart`. Continue the feature work.
5. Do not revert the current dirty worktree.

## Feature task still in progress

Continue the large OKAK Chat UI/functionality refactor:

- Errors must be shown as standalone banners, not assistant bubbles.
- Chat mode and Code mode are separate workspaces with separate chats/settings.
- Code mode needs context-window usage display and permission settings.
- Add file attachments to chat and code input.
- Move profile/settings into a popup opened from the lower-left profile button.
- Add sidebar hide/show.
- Add long system prompts for chat and agent/code modes.
- Add slash skill suggestions.
- Move chat list into the sidebar where Chat/History/Settings used to be.
- Add filtering/search for chats.
- Add routines/tool-call style expandable blocks, not only plain bubbles.
- Add model selection, reasoning, mode, context/limits under the input.
- Add Russian localization and language setting.
- Add close button on login screen.
- Fix Stop button if still broken.
- Add timestamps, copy, edit user message, and regenerate response.
- Add automatic chat title generation.
- Remove animated page slide transitions; switch instantly.

## Next concrete step

Finish `lib/features/shell/sidebar.dart` and the shell wrapper file first:

- collapsible sidebar
- new chat/new session button at top
- chat list in sidebar
- search/filter
- profile popup at bottom
- clean navigation to chat/code/settings/admin

After that, run analyzer/build and fix compile errors.
