import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:okakchat/core/providers/conversations_provider.dart';
import 'package:okakchat/core/providers/notifications_provider.dart';

final chatApiProvider = Provider((ref) => ChatApi(ref.watch(dioProvider)));

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.isError = false,
    DateTime? timestamp,
    String? id,
  })  : timestamp = timestamp ?? DateTime.now(),
        id = id ?? '${DateTime.now().microsecondsSinceEpoch}';

  final String role;
  String content;
  bool isStreaming;
  bool isError;
  final DateTime timestamp;
  final String id;

  ChatMessage copyWith({String? content, bool? isStreaming, bool? isError}) =>
      ChatMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        isError: isError ?? this.isError,
        timestamp: timestamp,
        id: id,
      );
}

// ── Presets for good system prompts ─────────────────────────────────────────

const kChatSystemPrompt = '''You are a helpful, thoughtful, and concise AI assistant.
You communicate clearly in the language the user writes in.
When answering questions, prefer depth over breadth unless the user asks otherwise.
Always be honest — if you don't know something, say so.
Format responses with markdown where it aids clarity: use headers for long answers,
code blocks for any code, bullet points for lists. Keep answers focused.''';

const kCodeSystemPrompt = '''You are an expert software engineer with deep knowledge
of multiple programming languages, frameworks, and best practices.
When writing code: always produce clean, production-ready, well-commented code.
Prefer modern idioms. Explain your reasoning briefly before or after the code.
When debugging: identify the root cause first, then propose the minimal fix.
When reviewing: be direct — point out bugs, performance issues, security flaws,
and style concerns. Use code blocks with language identifiers for all code snippets.''';

/// Returns a human-readable OS name for the current platform.
String _detectOsName() {
  if (kIsWeb) return 'Web (browser)';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  return 'unknown';
}

/// Per-OS shell hint baked into the runtime env block. Keeps the model from
/// suggesting GNU-only flags on macOS or POSIX-only paths on Windows.
String _shellFor() {
  if (kIsWeb) return 'n/a (browser sandbox)';
  if (Platform.isMacOS) return '/bin/zsh (BSD userland)';
  if (Platform.isLinux) return '/bin/bash (GNU coreutils)';
  if (Platform.isWindows) return 'PowerShell / cmd.exe';
  if (Platform.isIOS || Platform.isAndroid) return 'n/a (mobile sandbox)';
  return 'unknown';
}

String _osSpecificGuidance() {
  if (kIsWeb) {
    return 'You are running inside a browser. No filesystem or shell access — '
        'only conversational answers and code samples are possible.';
  }
  if (Platform.isMacOS) {
    return 'Prefer BSD-style flags. Examples: `sed -i "" ...`, '
        '`find . -name`, `ls -la`. Paths use forward slashes. '
        'Avoid GNU-only options like `sed -i` without an empty backup arg, '
        '`readlink -f`, `date --iso-8601`.';
  }
  if (Platform.isLinux) {
    return 'GNU coreutils available. `sed -i`, `readlink -f`, `xargs -r` are fine. '
        'Paths use forward slashes.';
  }
  if (Platform.isWindows) {
    return 'Use PowerShell semantics by default (`Get-ChildItem`, `Select-String`, '
        '`Copy-Item`). If a unix tool is needed, gate it behind WSL or git-bash. '
        'Paths use backslashes; quote paths containing spaces.';
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return 'You are running on a mobile device. There is no shell, no filesystem '
        'access, and no agent code execution. Do NOT propose shell commands or '
        'file edits — answer conversationally and provide code samples only.';
  }
  return '';
}

/// Builds the runtime environment block appended to the system prompt so
/// the model knows the actual platform / shell / workspace it is operating in.
String buildEnvironmentBlock({String workspacePath = ''}) {
  final os = _detectOsName();
  final shell = _shellFor();
  final cwd = workspacePath.isNotEmpty
      ? workspacePath
      : (!kIsWeb ? Directory.current.path : '(browser sandbox)');
  final guidance = _osSpecificGuidance();
  final pathSep = (!kIsWeb && Platform.isWindows) ? r'\\' : '/';
  return '''

<environment>
Operating system: $os
Shell: $shell
Workspace directory: $cwd
Path separator: $pathSep
$guidance
All file paths must be absolute unless explicitly relative to the workspace.
</environment>''';
}

class CodeModeSettings {
  const CodeModeSettings({
    this.allowFileEdits = false,
    this.allowCommands = false,
    this.allowNetworkAccess = false,
    this.workspacePath = '',
    this.agentMode = 'full',   // 'full' | 'plan' | 'ask'
    this.reasoningEnabled = false,
  });
  final bool allowFileEdits;
  final bool allowCommands;
  final bool allowNetworkAccess;
  final String workspacePath;
  final String agentMode;
  final bool reasoningEnabled;

  CodeModeSettings copyWith({
    bool? allowFileEdits,
    bool? allowCommands,
    bool? allowNetworkAccess,
    String? workspacePath,
    String? agentMode,
    bool? reasoningEnabled,
  }) =>
      CodeModeSettings(
        allowFileEdits: allowFileEdits ?? this.allowFileEdits,
        allowCommands: allowCommands ?? this.allowCommands,
        allowNetworkAccess: allowNetworkAccess ?? this.allowNetworkAccess,
        workspacePath: workspacePath ?? this.workspacePath,
        agentMode: agentMode ?? this.agentMode,
        reasoningEnabled: reasoningEnabled ?? this.reasoningEnabled,
      );
}

class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.selectedModel = 'gpt-4o',
    this.models = const [],
    this.temperature = 0.7,
    this.systemPrompt,
    this.maxTokens = 64000,
    this.contextLimit = 128000,
    this.attachedFiles = const [],
    this.codeSettings = const CodeModeSettings(),
  });
  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String selectedModel;
  final List<Map<String, dynamic>> models;
  final double temperature;
  final String? systemPrompt;
  final int maxTokens;
  final int contextLimit;
  final List<String> attachedFiles;
  final CodeModeSettings codeSettings;

  /// Rough token estimate: 4 chars ≈ 1 token
  int get estimatedTokensUsed {
    final totalChars = messages.fold<int>(
      0, (sum, m) => sum + m.content.length,
    );
    return (totalChars / 4).round();
  }

  double get contextFillFraction =>
      (estimatedTokensUsed / contextLimit).clamp(0.0, 1.0);

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? selectedModel,
    List<Map<String, dynamic>>? models,
    double? temperature,
    Object? systemPrompt = _sentinel,
    int? maxTokens,
    int? contextLimit,
    List<String>? attachedFiles,
    CodeModeSettings? codeSettings,
  }) =>
      ChatState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        selectedModel: selectedModel ?? this.selectedModel,
        models: models ?? this.models,
        temperature: temperature ?? this.temperature,
        systemPrompt: systemPrompt == _sentinel
            ? this.systemPrompt
            : systemPrompt as String?,
        maxTokens: maxTokens ?? this.maxTokens,
        contextLimit: contextLimit ?? this.contextLimit,
        attachedFiles: attachedFiles ?? this.attachedFiles,
        codeSettings: codeSettings ?? this.codeSettings,
      );
}

const _sentinel = Object();

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref, {this.isCodeMode = false})
      : super(ChatState(
          systemPrompt:
              isCodeMode ? kCodeSystemPrompt : kChatSystemPrompt,
        ));
  final Ref _ref;
  final bool isCodeMode;
  bool _cancelled = false;
  int _generationId = 0;
  int get generationId => _generationId;

  // ── Models ───────────────────────────────────────────────────────────────

  Future<void> loadModels() async {
    try {
      final models = await _ref.read(chatApiProvider).getModels();
      final modelList = models.cast<Map<String, dynamic>>();
      if (modelList.isEmpty) return;
      final defaultModel = modelList.first['id'] as String;
      final ctx = _contextLimitFor(modelList.first);
      state = state.copyWith(
        models: modelList,
        selectedModel: defaultModel,
        maxTokens: ctx,
        contextLimit: ctx,
      );
    } catch (_) {}
  }

  int _contextLimitFor(Map<String, dynamic> model) {
    // Try common API response keys for context window
    final raw = model['contextWindow'] ??
        model['maxTokens'] ??
        model['context_length'] ??
        model['max_context'] ??
        128000;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 128000;
  }

  Future<void> loadConversation(String id) async {
    state = state.copyWith(
      conversationId: id,
      messages: [],
      isLoading: true,
    );
    try {
      final msgs = await _ref.read(chatApiProvider).getMessages(id);
      state = state.copyWith(
        conversationId: id,
        messages: msgs
            .map((m) => ChatMessage(
                  role: m['role'] as String,
                  content: m['content'] as String,
                ))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      _showError(e.toString());
    }
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void selectModel(String modelId) {
    final model = state.models.cast<Map<String, dynamic>?>().firstWhere(
        (m) => m?['id'] == modelId, orElse: () => null);
    final ctx = model != null ? _contextLimitFor(model) : state.contextLimit;
    state = state.copyWith(
      selectedModel: modelId,
      maxTokens: ctx,
      contextLimit: ctx,
    );
  }
  void setTemperature(double v) => state = state.copyWith(temperature: v);
  void setSystemPrompt(String? v) => state = state.copyWith(systemPrompt: v);
  void setMaxTokens(int v) => state = state.copyWith(maxTokens: v);
  void setCodeSettings(CodeModeSettings s) =>
      state = state.copyWith(codeSettings: s);
  void addAttachedFile(String path) =>
      state = state.copyWith(
          attachedFiles: [...state.attachedFiles, path]);
  void removeAttachedFile(String path) =>
      state = state.copyWith(
          attachedFiles: state.attachedFiles.where((f) => f != path).toList());
  void clearAttachedFiles() =>
      state = state.copyWith(attachedFiles: []);

  void newChat() => state = ChatState(
        models: state.models,
        selectedModel: state.selectedModel,
        temperature: state.temperature,
        systemPrompt: isCodeMode ? kCodeSystemPrompt : kChatSystemPrompt,
        maxTokens: state.contextLimit,
        contextLimit: state.contextLimit,
        codeSettings: state.codeSettings,
      );

  // ── Stop ─────────────────────────────────────────────────────────────────

  bool get isCancelled => _cancelled;

  Completer<String>? _toolCancelCompleter;
  void registerToolCancelToken(Completer<String> c) =>
      _toolCancelCompleter = c;
  void clearToolCancelToken() => _toolCancelCompleter = null;

  void cancel() {
    AppLogger.state('cancel() — genId=$_generationId');
    _cancelled = true;
    _ref.read(wsClientProvider).cancel();
    if (_toolCancelCompleter != null && !_toolCancelCompleter!.isCompleted) {
      _toolCancelCompleter!.complete('Cancelled by user.');
    }
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String content,
      {List<Map<String, dynamic>>? tools}) async {
    _cancelled = false;
    _generationId++;
    AppLogger.state(
        'sendMessage — genId=$_generationId  tools=${tools?.map((t) => t["name"]).toList()}  msg="${AppLogger.trunc(content, 60)}"');
    final userMsg = ChatMessage(role: 'user', content: content);
    final assistantMsg =
        ChatMessage(role: 'assistant', content: '', isStreaming: true);

    final filesToSend = state.attachedFiles.map((path) {
      if (kIsWeb) return <String, String>{'name': path, 'content': ''};
      try {
        final file = File(path);
        final bytes = file.readAsBytesSync();
        final name = path.split('/').last;
        if (bytes.length > 50 * 1024 * 1024) {
          return <String, String>{
            'name': name,
            'content': '[File too large: $name]',
          };
        }
        final ext = name.contains('.') ? name.split('.').last : '';
        if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg']
            .contains(ext.toLowerCase())) {
          return <String, String>{
            'name': name,
            'content': '[Image attachment: $name]',
          };
        }
        return <String, String>{
          'name': name,
          'content': file.readAsStringSync(),
        };
      } catch (_) {
        return <String, String>{
          'name': path.split('/').last,
          'content': '[Error reading file]',
        };
      }
    }).toList();

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
      attachedFiles: [],
    );

    String? convId = state.conversationId;
    try {
      final title = content.length > 50
          ? '${content.substring(0, 50)}…'
          : content;
      convId ??= await _ref.read(chatApiProvider).createConversation(
            title,
            state.selectedModel,
            isCodeMode ? 'coding' : 'chat',
          );
      _ref.invalidate(conversationsProvider);
      await _ref.read(chatApiProvider).addMessage(convId, 'user', content);
    } catch (_) {}

    await _streamResponse(
      convId: convId,
      messages: state.messages.where((m) => !m.isStreaming).toList(),
      assistantMsg: assistantMsg,
      tools: tools,
      filesToSend: filesToSend,
      userContent: content,
    );
  }

  /// Continue after a tool result: re-sends the conversation to the AI.
  /// [args] is the original tool-call arguments so we can render a useful
  /// "command + output" summary instead of a bare result string.
  Future<void> continueWithToolResult(
    String toolName,
    String result, {
    Map<String, dynamic>? args,
    List<Map<String, dynamic>>? tools,
  }) async {
    if (_cancelled) return;
    _generationId++;
    final summary = _formatToolMessage(toolName, args ?? const {}, result);
    final toolMsg = ChatMessage(role: 'tool', content: summary);
    final assistantMsg =
        ChatMessage(role: 'assistant', content: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, toolMsg, assistantMsg],
      isLoading: true,
    );

    await _streamResponse(
      convId: state.conversationId,
      messages: state.messages.where((m) => !m.isStreaming).toList(),
      assistantMsg: assistantMsg,
      tools: tools,
    );
  }

  /// Renders a tool invocation + result in a shell-transcript style so it
  /// looks like a terminal session both to the model and to the user.
  String _formatToolMessage(
      String toolName, Map<String, dynamic> args, String result) {
    final trimmed = result.trim().isEmpty ? '(no output)' : result.trim();
    switch (toolName) {
      case 'execute_command':
        final cmd = args['command'] ?? '';
        return '\$ $cmd\n$trimmed';
      case 'read_file':
        return '\u2261 read ${args['path']}\n$trimmed';
      case 'list_directory':
        return '\u2261 ls ${args['path']}\n$trimmed';
      case 'search_files':
        return '\u2261 grep ${args['pattern']} ${args['path']}\n$trimmed';
      case 'write_file':
        return '\u2261 write ${args['path']}\n$trimmed';
      case 'edit_file':
        return '\u2261 edit ${args['path']}\n$trimmed';
      default:
        return '$toolName\n$trimmed';
    }
  }

  Future<void> _streamResponse({
    required String? convId,
    required List<ChatMessage> messages,
    required ChatMessage assistantMsg,
    List<Map<String, dynamic>>? tools,
    List<Map<String, String>>? filesToSend,
    String? userContent,
  }) async {
    final wsMessages = messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    // Append runtime environment so the model knows the real OS/shell/cwd.
    final basePrompt = state.systemPrompt ?? '';
    final envBlock = buildEnvironmentBlock(
        workspacePath: state.codeSettings.workspacePath);
    final effectivePrompt =
        basePrompt.isEmpty ? envBlock.trimLeft() : '$basePrompt$envBlock';

    final wsStream = _ref.read(wsClientProvider).stream(
          state.selectedModel,
          wsMessages,
          conversationId: convId,
          tools: tools,
          temperature: state.temperature,
          systemPrompt: effectivePrompt,
          maxTokens: state.maxTokens,
          files: filesToSend?.isNotEmpty == true ? filesToSend : null,
        );

    // Полный текст, который пришёл с сервера (может опережать UI).
    final incoming = StringBuffer();
    // Сколько символов уже показано в UI.
    var displayedLen = 0;
    var streamDone = false;
    Map<String, dynamic>? pendingToolCall;
    bool hadError = false;

    void pushToUi(int len) {
      if (len <= 0) return;
      assistantMsg.content = incoming.toString().substring(0, len);
      state = state.copyWith(
        conversationId: convId,
        messages: [...state.messages],
      );
    }

    // Typewriter: каждые 16мс выдаём в UI порцию символов, размер которой
    // зависит от backlog'а. Так даже если WS прислал 200 символов одним
    // фреймом, они «накапают» плавно, а не выпадут стеной.
    final typewriter = Stream.periodic(
      const Duration(milliseconds: 16),
      (_) => null,
    ).listen((_) {
      if (_cancelled) return;
      final total = incoming.length;
      if (displayedLen >= total) return;
      final backlog = total - displayedLen;
      // Базовая скорость ~3 символа/тик (~180 cps). При большом backlog
      // догоняем быстрее, чтобы не отставать на длинных ответах.
      final emit = backlog < 4
          ? backlog
          : streamDone
              ? math.max(6, backlog ~/ 3)
              : math.min(18, math.max(3, backlog ~/ 8));
      displayedLen = math.min(total, displayedLen + emit);
      pushToUi(displayedLen);
    });

    AppLogger.net('WS stream start — genId=$_generationId');
    try {
      await for (final chunk in wsStream) {
        if (_cancelled) break;
        if (chunk.done) {
          AppLogger.net('WS done — totalChars=${incoming.length}');
          break;
        }
        if (chunk.error != null) {
          AppLogger.err('WS error: ${chunk.error}');
          hadError = true;
          _showError(chunk.error!);
          break;
        }
        if (chunk.content != null) {
          incoming.write(chunk.content);
        }
        if (chunk.toolCall != null) {
          final fn = (chunk.toolCall!['function'] as Map?)?.cast<String, dynamic>();
          AppLogger.net('WS toolCall: ${fn?["name"]} args=${AppLogger.trunc(fn?["arguments"]?.toString() ?? "", 80)}');
          pendingToolCall = chunk.toolCall;
        }
      }
      streamDone = true;
      // Дренаж: даём typewriter догнать поток, но не дольше ~600мс.
      final deadline = DateTime.now().add(const Duration(milliseconds: 600));
      while (displayedLen < incoming.length &&
          DateTime.now().isBefore(deadline) &&
          !_cancelled) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      // Финальный flush — гарантированно отдать остаток.
      if (!_cancelled && displayedLen < incoming.length) {
        displayedLen = incoming.length;
        pushToUi(displayedLen);
      }
    } catch (e) {
      hadError = true;
      if (!_cancelled) _showError(e.toString());
    } finally {
      await typewriter.cancel();
    }

    if (_cancelled || hadError) {
      state = state.copyWith(
        conversationId: convId,
        messages: state.messages
            .where((m) => m.id != assistantMsg.id)
            .toList(),
        isLoading: false,
      );
    } else {
      assistantMsg.isStreaming = false;
      try {
        if (convId != null) {
          await _ref
              .read(chatApiProvider)
              .addMessage(convId, 'assistant', assistantMsg.content);
          if (state.conversationId == null && userContent != null) {
            final betterTitle =
                _generateTitle(userContent, assistantMsg.content);
            await _ref
                .read(chatApiProvider)
                .updateConversation(convId, title: betterTitle);
            _ref.invalidate(conversationsProvider);
          }
        }
      } catch (_) {}
      state = state.copyWith(
        conversationId: convId,
        messages: [...state.messages],
        isLoading: false,
      );
    }

    if (pendingToolCall != null && !_cancelled && !hadError) {
      _pendingToolCallController.add(pendingToolCall);
    }
  }

  // ── Message editing ──────────────────────────────────────────────────────

  Future<void> editAndRegenerate(String messageId, String newContent) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    // Truncate history at this message (inclusive of response after it)
    final truncated = state.messages.sublist(0, idx);
    state = state.copyWith(messages: truncated);
    await sendMessage(newContent);
  }

  Future<void> regenerateLast() async {
    // Find last user message
    final messages = state.messages;
    int userIdx = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        userIdx = i;
        break;
      }
    }
    if (userIdx < 0) return;

    final lastUserContent = messages[userIdx].content;
    final truncated = messages.sublist(0, userIdx);
    state = state.copyWith(messages: truncated);
    await sendMessage(lastUserContent);
  }

  // ── Tool calls ───────────────────────────────────────────────────────────

  final _pendingToolCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get toolCallStream =>
      _pendingToolCallController.stream;

  void addToolResult(String toolName, String result) {
    final toolMsg = ChatMessage(role: 'tool', content: result);
    state = state.copyWith(messages: [...state.messages, toolMsg]);
  }

  String _generateTitle(String userMsg, String assistantMsg) {
    // Find a natural break point in the user message
    final breakChars = ['.', '!', '?', '\n', ','];
    var end = userMsg.length;
    for (final c in breakChars) {
      final idx = userMsg.indexOf(c);
      if (idx > 0 && idx < end) end = idx;
    }
    var title = userMsg.substring(0, end > 40 ? 40 : end).trim();
    if (title.length > 40) title = '${title.substring(0, 40)}…';
    if (title.isEmpty) title = 'New chat';
    return title;
  }

  // ── Notifications ────────────────────────────────────────────────────────

  void _showError(String raw) {
    final msg = _friendlyError(raw);
    _ref.read(notificationsProvider.notifier).showError(msg);
  }

  String _friendlyError(String raw) {
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'Session expired. Please sign in again.';
    }
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'Cannot reach the server. Check your network connection.';
    }
    if (raw.contains('timeout') || raw.toLowerCase().contains('timed out')) {
      return 'Request timed out. The server might be busy.';
    }
    return 'AI service error. Please try again.';
  }

  @override
  void dispose() {
    _pendingToolCallController.close();
    super.dispose();
  }
}

// ── Two separate providers (chat and code) ───────────────────────────────────

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
        (ref) => ChatNotifier(ref, isCodeMode: false));

final codeProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
        (ref) => ChatNotifier(ref, isCodeMode: true));
