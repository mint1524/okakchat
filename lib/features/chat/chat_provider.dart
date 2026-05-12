import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/core/api/ws_client.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

final chatApiProvider = Provider((ref) => ChatApi(ref.watch(dioProvider)));

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });
  final String role;
  String content;
  bool isStreaming;
}

class ChatState {
  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isLoading = false,
    this.selectedModel = 'gpt-4o',
    this.models = const [],
    this.mode = 'chat',
    this.temperature = 0.7,
    this.systemPrompt,
    this.maxTokens = 4096,
  });
  final String? conversationId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String selectedModel;
  final List<Map<String, dynamic>> models;
  final String mode;
  final double temperature;
  final String? systemPrompt;
  final int maxTokens;

  ChatState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? selectedModel,
    List<Map<String, dynamic>>? models,
    String? mode,
    double? temperature,
    Object? systemPrompt = _sentinel,
    int? maxTokens,
  }) =>
      ChatState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        selectedModel: selectedModel ?? this.selectedModel,
        models: models ?? this.models,
        mode: mode ?? this.mode,
        temperature: temperature ?? this.temperature,
        systemPrompt: systemPrompt == _sentinel
            ? this.systemPrompt
            : systemPrompt as String?,
        maxTokens: maxTokens ?? this.maxTokens,
      );
}

const _sentinel = Object();

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());
  final Ref _ref;

  Future<void> loadModels() async {
    final models = await _ref.read(chatApiProvider).getModels();
    final modelList = models.cast<Map<String, dynamic>>();
    final defaultModel =
        modelList.isNotEmpty ? modelList.first['id'] as String : 'gpt-4o';
    state = state.copyWith(
      models: modelList,
      selectedModel: defaultModel,
    );
  }

  Future<void> loadConversation(String id) async {
    state = state.copyWith(conversationId: id, isLoading: true);
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
  }

  void selectModel(String modelId) =>
      state = state.copyWith(selectedModel: modelId);
  void setMode(String mode) => state = state.copyWith(mode: mode);
  void setTemperature(double v) => state = state.copyWith(temperature: v);
  void setSystemPrompt(String? v) =>
      state = state.copyWith(systemPrompt: v);
  void setMaxTokens(int v) => state = state.copyWith(maxTokens: v);

  void newChat() => state = ChatState(
        models: state.models,
        selectedModel: state.selectedModel,
        temperature: state.temperature,
        systemPrompt: state.systemPrompt,
        maxTokens: state.maxTokens,
      );

  Future<void> sendMessage(String content,
      {List<Map<String, dynamic>>? tools}) async {
    final userMsg = ChatMessage(role: 'user', content: content);
    final assistantMsg =
        ChatMessage(role: 'assistant', content: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isLoading: true,
    );

    // Create conversation if needed
    String? convId = state.conversationId;
    convId ??= await _ref.read(chatApiProvider).createConversation(
          content.length > 40 ? '${content.substring(0, 40)}…' : content,
          state.selectedModel,
          state.mode,
        );

    // Persist user message
    await _ref.read(chatApiProvider).addMessage(convId, 'user', content);

    // Build messages list for API (exclude currently-streaming assistant msg)
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

    await for (final chunk in wsStream) {
      if (chunk.done) break;
      if (chunk.error != null) {
        assistantMsg.content = 'Error: ${chunk.error}';
        break;
      }
      if (chunk.content != null) {
        buffer.write(chunk.content);
        assistantMsg.content = buffer.toString();
        // Trigger rebuild
        state = state.copyWith(
          conversationId: convId,
          messages: [...state.messages],
        );
      }
      if (chunk.toolCall != null) {
        pendingToolCall = chunk.toolCall;
      }
    }

    assistantMsg.isStreaming = false;
    await _ref
        .read(chatApiProvider)
        .addMessage(convId, 'assistant', assistantMsg.content);

    state = state.copyWith(
      conversationId: convId,
      messages: [...state.messages],
      isLoading: false,
    );

    // If there's a pending tool call, emit it so agent can handle it
    if (pendingToolCall != null) {
      _pendingToolCallController.add(pendingToolCall);
    }
  }

  // Tool call stream for agent mode
  final _pendingToolCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get toolCallStream =>
      _pendingToolCallController.stream;

  void addToolResult(String toolName, String result) {
    final toolMsg = ChatMessage(role: 'tool', content: result);
    state = state.copyWith(messages: [...state.messages, toolMsg]);
  }

  @override
  void dispose() {
    _pendingToolCallController.close();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
