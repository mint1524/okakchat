import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/auth/token_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  Stream<WsStreamResult> stream(
    String modelId,
    List<Map<String, dynamic>> messages, {
    String? conversationId,
    List<Map<String, dynamic>>? tools,
  }) async* {
    final token = await TokenStorage.getAccessToken();
    _channel = WebSocketChannel.connect(
      Uri.parse('$_wsBaseUrl/api/ai/stream'),
    );

    // Wait for connection to be established
    await _channel!.ready;

    final payload = jsonEncode({
      'model': modelId,
      'messages': messages,
      if (conversationId != null) 'conversationId': conversationId,
      if (tools != null) 'tools': tools,
      // token sent in first frame for WS auth (server reads from JWT)
    });
    _channel!.sink.add(payload);

    await for (final raw in _channel!.stream) {
      final data = raw as String;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        if (json['done'] == true) {
          yield const WsStreamResult(done: true);
          break;
        }
        if (json['error'] != null) {
          yield WsStreamResult(error: json['error'] as String);
          break;
        }
        // OpenAI SSE chunk format
        final choices = json['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final delta = (choices.first as Map<String, dynamic>)['delta']
              as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          final toolCalls = delta?['tool_calls'] as List?;
          if (content != null) yield WsStreamResult(content: content);
          if (toolCalls != null && toolCalls.isNotEmpty) {
            yield WsStreamResult(
                toolCall: toolCalls.first as Map<String, dynamic>);
          }
        }
      } catch (_) {}
    }
  }

  void cancel() {
    _channel?.sink.close();
    _channel = null;
  }
}

final wsClientProvider = Provider((ref) => WsClient());
