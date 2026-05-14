# CHECKPOINT — 15 May 2026

**Build:** `dart analyze lib/` — No issues found

---

## Что сделано

### 1. Инлайн-маркдаун (message_bubble.dart)
- `_CodeBuilder` теперь отличает inline code от fenced code blocks: если код короткий (<80 символов) и без `\n`, возвращает `null` → MarkdownStyleSheet.code обрабатывает как инлайн
- Inline code перестал рендериться как отдельный блок plaintext

### 2. Контекстное окно из API (chat_provider.dart)
- Добавлено поле `contextLimit` в `ChatState` — полный контекст модели
- `loadModels()` теперь парсит `contextWindow`/`maxTokens`/`context_length`/`max_context` из ответа API
- `selectModel()` автоматически обновляет `maxTokens` и `contextLimit` при смене модели
- `contextFillFraction` теперь считается от `contextLimit`, а не от `maxTokens`
- `newChat()` сохраняет `contextLimit` модели

### 3. Агентский режим (code_screen.dart)
- Добавлен `_AgentStatusBar` — статусная строка под top bar: спиннер + `· Transfiguring… (3m 49s · ↑ 8.4k tokens)`
- Таймер отслеживает elapsed time во время стриминга
- Менеджер статуса (`_updateStatus`) показывает разный текст для full/plan/ask режимов
- `_ToolCallInline` — инструменты (tool calls) отображаются inline с детекцией типа (Edit/Run/Read/Search)
- Tool calls можно сворачивать/разворачивать
- Формирование частиц на фоне (ParticleFormation) зависит от режима: gear (full), brain (plan), code (ask)

### 4. Дизайн (chat_input.dart, model_selector.dart)
- **Модель без рамки**: `_ModelDropdown` — просто текст + иконка + chevron, без контейнера/рамки
- **Кнопки без рамок**: `_SendButton` — без shadow/border, `_StopButton` — без border, `_AttachBtn` — 32×32 без фона
- **Скрепка в поле ввода**: `_AttachBtn` встроена внутрь `Container` текстового поля, слева от `TextField`
- **Bottom bar**: Settings и Model selector — всё минималистично, мелкий текст, без рамок
- **Контекст**: _ContextChip показывает % от `contextLimit`

### 5. Плавный стриминг (message_bubble.dart)
- Во время стриминга MarkdownBody рендерится напрямую (без AnimatedSwitcher) — никаких лишних crossfade-анимаций на каждом чанке
- AnimatedSwitcher остаётся только для финального (не streaming) сообщения — плавный переход при завершении

### 6. Анимация звёзд (animated_background.dart)
- Добавлен `ParticleFormation` enum: `none`, `circle`, `hammer`, `code`, `brain`, `gear`
- `AnimatedBackground` принимает `formation` и `formationProgress`
- Частицы плавно перелетают (lerp) в целевые позиции при смене формации
- 6 shape-генераторов: circle (кольцо), hammer (молоток), code (</>), brain (нейро-форма), gear (шестерёнка)
- FPS контролируется через AnimationController (1s repeat — ~60fps с учётом vsync)

### 7. Скиллы (chat_input.dart, code_screen.dart)
- Добавлено 8 новых slash skills: `/arch`, `/api`, `/db`, `/deploy`, `/ci`, `/fix`, `/pr`, `/commit`
- В Code пустой экран добавлены 3 GitHub-подсказки: "Set up GitHub Actions CI", "Write a GitHub workflow", "Review this PR for issues"

---

## Изменённые файлы

| File | Changes |
|------|---------|
| `lib/core/widgets/animated_background.dart` | ParticleFormation shapes, lerp animation, target positions |
| `lib/features/chat/chat_provider.dart` | contextLimit, _contextLimitFor, selectModel context update |
| `lib/features/chat/message_bubble.dart` | inline code fix, streaming без AnimatedSwitcher |
| `lib/features/chat/chat_input.dart` | frameless model/buttons, attach in input, +8 skills |
| `lib/features/chat/code_screen.dart` | AgentStatusBar, ToolCallInline, status timer, particle formations |
| `CHECKPOINT.md` | этот файл |

---

## Что осталось (если нужно продолжать)

1. **Agent file operations** — реальная интеграция `DesktopToolExecutor` с code_screen для чтения/записи файлов из агента
2. **GitHub skills** — установка GitHub Actions workflows через UI в code mode
3. **Anthropic skills** — интеграция с Anthropic API (Claude Code)
4. **Мобильная адаптация** — проверить и донастроить compact layout на телефонах
5. **Backend контекст** — если API не возвращает `contextWindow`, донастроить парсер в `_contextLimitFor`

---

## Команда проверки

```bash
dart analyze lib/
```
