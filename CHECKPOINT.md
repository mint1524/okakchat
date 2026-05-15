# CHECKPOINT — 15 May 2026

**Build:** `dart analyze lib/` — No issues found
**Branch:** `main` (clean worktree)
**HEAD:** `7bb44c8 feat(agent): wire agent loop with tool execution and confirmation`

---

## Agent loop — текущее состояние

### Поведение подтверждений (code_screen.dart `_handleToolCall`)
Как в Claude / Codex:
- **`full` (bypass)** — никогда не спрашивает, авто-исполнение всех тулов
- **`ask` / `plan`** — диалог подтверждения для **любого** tool call
- Для `execute_command` диалог помечается `⚠ Run command?` и кнопкой `Run`
- При Deny — `continueWithToolResult(toolName, 'User skipped this action.', …)`

### Multi-turn (AI вызывает несколько тулов подряд)
Архитектура:
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
События приходят сериально: новый `tool_use` возможен только после следующего стрима. Многотуловая цепочка поддерживается.

### Защита от race conditions
- `_cancelled` flag + публичный `isCancelled` getter
- `_generationId` инкрементится в `sendMessage` и `continueWithToolResult`
- `_handleToolCall` захватывает `genAtStart` до `dispatch`, после — проверяет:
  - `if (isCancelled) return;`
  - `if (generationId != genAtStart) return;` — пользователь начал новый чат пока тул выполнялся

### UI агента (code_screen)
- `_processing` flag → `LinearProgressIndicator` во время dispatch
- `_AgentStatusBar` с `· Executing tool…` если `_statusText` пуст
- `_ToolCallInline` карточки в стриме (expandable)

---

## Что осталось

1. **End-to-end тест агентного цикла** в запущенном приложении: `создай файл foo.txt` → `теперь отредактируй его` (две AI-итерации с разными тулами)
2. Проверить отмену во время `execute_command` (длинная команда + Stop)
3. UX: возможно показывать `Tool executed (N)` счётчик в status bar при multi-turn

---

## Команда проверки

```bash
/Users/min7t/flutter/bin/dart analyze lib/
```

## Ключевые файлы

| File | Role |
|------|------|
| `lib/features/chat/chat_provider.dart` | `ChatNotifier`: `sendMessage`, `_streamResponse`, `continueWithToolResult`, `toolCallStream`, `isCancelled`, `generationId` |
| `lib/features/chat/code_screen.dart` | агентный UI, `_handleToolCall`, `_showToolConfirm`, race-guards |
| `lib/features/agent/tool_definitions.dart` | `agentTools` (read_file, list_directory, search_files, write_file, edit_file, execute_command) |
| `lib/features/agent/tools/tool_executor.dart` | `DesktopToolExecutor.dispatch(name, args)` |
