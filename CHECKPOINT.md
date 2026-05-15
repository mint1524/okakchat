# CHECKPOINT — 15 May 2026

**Build:** `dart analyze lib/` — No issues found
**Branch:** `main` (clean worktree)
**HEAD:** `b7c59c6 fix(code): crash, bubbles, Linux-bias, streaming, model picker`

---

## Свежие правки (этой сессии)

### 1. AnimatedBackground crash «field has not been initialized»
`lib/core/widgets/animated_background.dart` — `_particles` объявлен `late final`, но `initState` отсутствовал и инициализация падала на первом `build()`.

Добавлено в `initState`:
```dart
_particles = List.generate(
  widget.particleCount,
  (_) => _Particle.random(_rng),
);
_assignShapeTargets();
```

### 2. Переключение чатов в сайдбаре не работало
`lib/features/chat/chat_screen.dart` — при навигации `/chat/abc → /chat/xyz` GoRouter иногда переиспользует State, а `didUpdateWidget` не был реализован → старые сообщения оставались на экране.

Добавлен `didUpdateWidget`, который при смене `widget.conversationId` дёргает `loadConversation(...)` (или `newChat()` для `null`).

### 3. Code-mode redesign (commit b7c59c6)
- **Positioned/StackParentData crash** в `code_screen.dart` — убран условный `Positioned` в `Column`. Прогресс-бар теперь как 2px слот в самом верху колонки.
- **`<environment>` блок в system prompt** (`chat_provider.dart`) — реальная OS / shell / cwd, чтобы модель не считала окружение Linux и не предлагала неверные команды.
- **Flat Claude-Code transcript** — никаких бабблов, левый рельс с маркерами `> user` / `✦ assistant`. На десктопе убрана правая `_CodeOutputPanel`, диалог теперь во всю ширину.
- **Smooth streaming** — assistant updates троттлятся до ~30 fps + финальный flush; перестали пере-рендерить весь `ListView` на каждый токен.
- **Tool-call display** — shell-style (`$ cmd` / `≡ read path`), сворачиваемое тело output, иконки по типу тула.
- **`ModelPickerButton`** (вкладки компаний + варианты + thinking-уровни) — портирован из `origin/nikita` поверх main-only `chat_input` (20 skills, attach button, per-model contextLimit).

---

## Agent loop — текущее состояние

### Поведение подтверждений (code_screen.dart `_handleToolCall`)
Как в Claude / Codex:
- **`full` (bypass)** — никогда не спрашивает, авто-исполнение всех тулов
- **`ask` / `plan`** — диалог подтверждения для **любого** tool call
- Для `execute_command` диалог помечается `⚠ Run command?` и кнопкой `Run`
- При Deny — `continueWithToolResult(toolName, 'User skipped this action.', …)`

### Multi-turn (AI вызывает несколько тулов подряд)
```
AI stream → pendingToolCall (chunk.toolCall)
         → stream done
         → _pendingToolCallController.add(pendingToolCall)
         → code_screen listener → _handleToolCall
         → DesktopToolExecutor.dispatch
         → continueWithToolResult(toolName, result)
         → новый _streamResponse → AI snova может emit tool_use
         → цикл
```
События сериальные: новый `tool_use` возможен только после следующего стрима.

### Защита от race conditions
- `_cancelled` flag + публичный `isCancelled` getter
- `_generationId` инкрементится в `sendMessage` и `continueWithToolResult`
- `_handleToolCall` захватывает `genAtStart` до `dispatch`, после — проверяет:
  - `if (isCancelled) return;`
  - `if (generationId != genAtStart) return;`

### UI агента (code_screen)
- `_processing` flag → `LinearProgressIndicator` (2px slot в верху колонки)
- `_AgentStatusBar` с `· Executing tool…` если `_statusText` пуст
- Inline tool-call карточки в shell-transcript стиле

---

## Что осталось

1. **End-to-end тест агентного цикла** в запущенном приложении: `создай файл foo.txt` → `теперь отредактируй его` (две AI-итерации с разными тулами).
2. Проверить отмену во время `execute_command` (длинная команда + Stop).
3. UX: возможно показывать `Tool executed (N)` счётчик в status bar при multi-turn.
4. Smoke-test переключения чатов и формаций фона (regression для свежих fix).

---

## Команда проверки

```bash
/Users/min7t/flutter/bin/dart analyze lib/
```

## Ключевые файлы

| File | Role |
|------|------|
| `lib/features/chat/chat_provider.dart` | `ChatNotifier`: `sendMessage`, `_streamResponse`, `continueWithToolResult`, `toolCallStream`, `isCancelled`, `generationId`, `<environment>` injection |
| `lib/features/chat/chat_screen.dart` | стандартный чат, теперь с `didUpdateWidget` для смены `conversationId` |
| `lib/features/chat/code_screen.dart` | агентный UI, flat transcript, `_handleToolCall`, `_showToolConfirm`, race-guards |
| `lib/features/chat/chat_input.dart` | 20 skills, attach button, per-model contextLimit |
| `lib/features/chat/model_picker.dart` | `ModelPickerButton` — вкладки компаний + варианты + thinking levels |
| `lib/features/agent/tool_definitions.dart` | `agentTools` (read_file, list_directory, search_files, write_file, edit_file, execute_command) |
| `lib/features/agent/tools/tool_executor.dart` | `DesktopToolExecutor.dispatch(name, args)` |
| `lib/core/widgets/animated_background.dart` | partikle formations, теперь с корректным `initState` |
