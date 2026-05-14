import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/api_client.dart';
import 'package:okakchat/core/auth/session_tokens.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

const _wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'ws://localhost:80',
);

class WsStreamResult {
  const WsStreamResult({
    this.content,
    this.toolCall,
    this.done = false,
    this.error,
  });
  final String? content;
  final Map<String, dynamic>? toolCall;
  final bool done;
  final String? error;
}

class WsClient {
  WebSocketChannel? _channel;
  StreamController<WsStreamResult>? _controller;

  Stream<WsStreamResult> stream(
    String modelId,
    List<Map<String, dynamic>> messages, {
    String? conversationId,
    List<Map<String, dynamic>>? tools,
    double? temperature,
    String? systemPrompt,
    int? maxTokens,
  }) {
    // Cancel any running stream first
    cancel();

    _controller = StreamController<WsStreamResult>();

    _run(
      modelId: modelId,
      messages: messages,
      conversationId: conversationId,
      tools: tools,
      temperature: temperature,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
    );

    return _controller!.stream;
  }

  Future<void> _run({
    required String modelId,
    required List<Map<String, dynamic>> messages,
    String? conversationId,
    List<Map<String, dynamic>>? tools,
    double? temperature,
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final ctrl = _controller!;
    try {
      final token = await getValidAccessToken(apiBaseUrl);
      if (token == null) {
        ctrl.add(const WsStreamResult(error: 'Unauthorized'));
        return;
      }

      if (!kIsWeb) {
        _channel = IOWebSocketChannel.connect(
          Uri.parse('$_wsBaseUrl/api/ai/stream'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        _channel = WebSocketChannel.connect(
          Uri.parse('$_wsBaseUrl/api/ai/stream'),
        );
      }

      await _channel!.ready;

      final payload = jsonEncode({
        'model': modelId,
        'messages': messages,
        if (conversationId != null) 'conversationId': conversationId,
        if (tools != null) 'tools': tools,
        if (temperature != null) 'temperature': temperature,
        if (systemPrompt != null && systemPrompt.isNotEmpty)
          'systemPrompt': systemPrompt,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (kIsWeb) '_token': token,
      });
      _channel!.sink.add(payload);

      await for (final raw in _channel!.stream) {
        if (ctrl.isClosed) break;
        final data = raw as String;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (json['done'] == true) {
            ctrl.add(const WsStreamResult(done: true));
            break;
          }
          if (json['error'] != null) {
            ctrl.add(WsStreamResult(error: json['error'] as String));
            break;
          }
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = (choices.first as Map<String, dynamic>)['delta']
                as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            final toolCalls = delta?['tool_calls'] as List?;
            if (content != null) ctrl.add(WsStreamResult(content: content));
            if (toolCalls != null && toolCalls.isNotEmpty) {
              ctrl.add(WsStreamResult(
                  toolCall: toolCalls.first as Map<String, dynamic>));
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (!ctrl.isClosed) {
        ctrl.add(WsStreamResult(error: e.toString()));
      }
    } finally {
      if (!ctrl.isClosed) ctrl.close();
      _channel = null;
    }
  }

  void cancel() {
    _controller?.close();
    _controller = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}

final wsClientProvider = Provider((ref) => WsClient());
