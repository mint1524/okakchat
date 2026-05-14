# OKAK Chat OpenCode Start Prompt

You are working in the Flutter app repository:

```text
/Users/min7t/OKAK APP v3/okakchat
```

Talk to the user in Russian. Do the engineering work directly. Do not ask broad clarifying questions unless the repository state makes progress impossible.

## Current Situation

This repository has an in-progress Flutter UI/product refactor that was started in another agent session and then interrupted. Continue from the dirty worktree. Do not revert existing changes.

The prior work focused on redesigning OKAK Chat into a more serious Claude/Codex-like app:

- `chat_provider.dart`: message ids, timestamps, edit/regenerate support, stop/cancel work, automatic titles.
- `ws_client.dart`: websocket cancellation/stop handling.
- `message_bubble.dart`: timestamps, copy/edit actions, expandable routine/tool-call style sections.
- `chat_input.dart`: attachments, slash suggestions, controls below input.
- `model_settings_sheet.dart`: simplified presets and model settings.
- `chat_screen.dart`: redesigned main chat layout.
- `code_screen.dart`: separate code/agent mode UI.
- `sidebar.dart`: started moving chat list/search/profile/navigation into sidebar.
- New support files under `lib/core/l10n/`, `lib/core/providers/`, and `lib/core/widgets/notification_banner.dart`.

## Important Rules

- Preserve the dirty worktree. Do not reset, checkout, or revert changes unless explicitly asked.
- Use `rg --files` or `ls` to discover files. Do not invent file paths.
- Read files in small chunks with `sed -n`, not large `cat` calls over huge files.
- Avoid parallel command batches while recovering context. Run one command at a time if a failure would interrupt other reads.
- Keep edits focused. Finish one slice, run checks, then continue.
- Use ASCII in code/comments unless the file already uses non-ASCII user-facing strings.
- Do not put secrets in repo files.

## Current Dirty Files

Expect changes in these files and directories:

```text
CHECKPOINT.md
OPENCODE_START.md
opencode.json
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

## Product Goal

Complete the OKAK Chat refactor:

- Show AI/API errors as standalone banners, not as assistant message bubbles.
- Keep Chat mode and Code mode as separate workspaces with separate chats and settings.
- Code mode should show context-window usage and permission settings.
- Add file attachments in both chat and code modes.
- Move profile/settings into a popup opened from the lower-left profile button.
- Add sidebar hide/show.
- Add long, high-quality system prompts for normal chat and code/agent modes.
- Add slash skill suggestions.
- Move chat/session list into the sidebar and add filtering/search.
- Render tool/routine activity as expandable blocks, not just plain message bubbles.
- Put model selection, reasoning, mode, context/limits controls under the message input.
- Add Russian localization and a language setting.
- Add a close button on the login screen.
- Fix Stop if it is still broken.
- Add timestamps, whole-message copy, user-message edit, and response regeneration.
- Add automatic chat title generation.
- Remove animated route/page slide transitions; route switches should be instant.

## First Slice To Finish

Start with the shell/sidebar slice only:

1. Run:

```bash
git status --short
rg --files lib/features/shell lib/features/chat lib/core | sort
ls lib/features/shell/
```

2. Read these real files in chunks:

```bash
sed -n '1,260p' lib/features/shell/sidebar.dart
sed -n '261,560p' lib/features/shell/sidebar.dart
sed -n '561,1040p' lib/features/shell/sidebar.dart
sed -n '1,260p' lib/features/shell/*_shell.dart
```

3. Finish `sidebar.dart` and the shell wrapper file:

- collapsible sidebar
- visible re-open affordance when collapsed
- new chat/new session action at top
- chat/code mode switch
- chat list in sidebar
- search/filter for chats
- profile popup at bottom
- settings/admin navigation
- clean mobile/desktop behavior

4. Only after sidebar/shell is coherent, run static checks and fix compile errors:

```bash
dart analyze
```

If `dart` or `flutter` is not on PATH, locate the local Flutter SDK or ask the user for the exact command. Do not guess destructive commands.

## Commit Guidance

Do not commit until the user asks. When the implementation reaches a coherent checkpoint, summarize:

- files changed
- what works now
- remaining compile/runtime issues
- exact command used for verification

