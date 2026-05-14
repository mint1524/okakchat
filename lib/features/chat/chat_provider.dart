import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/auth/auth_provider.dart';
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

const kChatSystemPrompt = '''You are a helpful, thoughtful, and concise AI assistant. \
You communicate clearly in the language the user writes in. \
When answering questions, prefer depth over breadth unless the user asks otherwise. \
Always be honest — if you don't know something, say so. \
Format responses with markdown where it aids clarity: use headers for long answers, \
code blocks for any code, bullet points for lists. Keep answers focused.''';

const kCodeSystemPrompt = '''You are an expert software engineer with deep knowledge \
of multiple programming languages, frameworks, and best practices. \
When writing code: always produce clean, production-ready, well-commented code. \
Prefer modern idioms. Explain your reasoning briefly before or after the code. \
When debugging: identify the root cause first, then propose the minimal fix. \
When reviewing: be direct — point out bugs, performance issues, security flaws, \
and style concerns. Use code blocks with language identifiers for all code snippets.''';

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
    this.maxTokens = 4096,
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
  final List<String> attachedFiles;     // file paths or names
  final CodeModeSettings codeSettings;

  /// Rough token estimate: 4 chars ≈ 1 token
  int get estimatedTokensUsed {
    final totalChars = messages.fold<int>(
      0, (sum, m) => sum + m.content.length,
    );
    return (totalChars / 4).round();
  }

  double get contextFillFraction =>
      (estimatedTokensUsed / maxTokens).clamp(0.0, 1.0);

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? selectedModel,
    List<Map<String, dynamic>>? models,
    double? temperature,
    Object? systemPrompt = _sentinel,
    int? maxTokens,
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

  // ── Models ───────────────────────────────────────────────────────────────

  Future<void> loadModels() async {
    try {
      final models = await _ref.read(chatApiProvider).getModels();
      final modelList = models.cast<Map<String, dynamic>>();
      final defaultModel =
          modelList.isNotEmpty ? modelList.first['id'] as String : 'gpt-4o';
      state = state.copyWith(models: modelList, selectedModel: defaultModel);
    } catch (_) {}
  }

  Future<void> loadConversation(String id) async {
    state = state.copyWith(conversationId: id, isLoading: true);
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

  void selectModel(String modelId) =>
      state = state.copyWith(selectedModel: modelId);
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
        maxTokens: state.maxTokens,
        codeSettings: state.codeSettings,
      );

  // ── Stop ─────────────────────────────────────────────────────────────────

  void cancel() {
    _cancelled = true;
    _ref.read(wsClientProvider).cancel();
  }

  // ── Send message ─────────────────────────────────────────────────────────

  Future<void> sendMessage(String content,
      {List<Map<String, dynamic>>? tools}) async {
    _cancelled = false;
    final userMsg = ChatMessage(role: 'user', content: content);
    final assistantMsg =
        ChatMessage(role: 'assistant', content: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
      attachedFiles: [],  // clear after send
    );

    String? convId = state.conversationId;
    try {
      // Auto-title from first message
      final title = content.length > 50
          ? '${content.substring(0, 50)}…'
          : content;
      convId ??= await _ref.read(chatApiProvider).createConversation(
            title,
            state.selectedModel,
            isCodeMode ? 'coding' : 'chat',
          );

      await _ref.read(chatApiProvider).addMessage(convId, 'user', content);
    } catch (_) {}

    final wsMessages = state.messages
        .where((m) => !m.isStreaming)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final wsStream = _ref.read(wsClientProvider).stream(
          state.selectedModel,
          wsMessages,
          conversationId: convId,
          tools: tools,
          temperature: state.temperature,
          systemPrompt: state.systemPrompt,
          maxTokens: state.maxTokens,
        );

    final buffer = StringBuffer();
    Map<String, dynamic>? pendingToolCall;
    bool hadError = false;

    try {
      await for (final chunk in wsStream) {
        if (_cancelled) break;
        if (chunk.done) break;
        if (chunk.error != null) {
          hadError = true;
          _showError(chunk.error!);
          break;
        }
        if (chunk.content != null) {
          buffer.write(chunk.content);
          assistantMsg.content = buffer.toString();
          state = state.copyWith(
            conversationId: convId,
            messages: [...state.messages],
          );
        }
        if (chunk.toolCall != null) {
          pendingToolCall = chunk.toolCall;
        }
      }
    } catch (e) {
      hadError = true;
      if (!_cancelled) _showError(e.toString());
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
