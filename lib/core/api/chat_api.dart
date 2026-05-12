import 'package:dio/dio.dart';

class ChatApi {
  ChatApi(this._dio);
  final Dio _dio;

  Future<List<dynamic>> getConversations({bool archived = false}) async {
    final res = await _dio.get('/api/chat/conversations',
        queryParameters: {'archived': archived});
    return res.data as List<dynamic>;
  }

  Future<String> createConversation(
      String title, String modelId, String mode) async {
    final res = await _dio.post('/api/chat/conversations',
        data: {'title': title, 'modelId': modelId, 'mode': mode});
    return (res.data as Map<String, dynamic>)['id'] as String;
  }

  Future<List<dynamic>> getMessages(String conversationId) async {
    final res = await _dio
        .get('/api/chat/conversations/$conversationId/messages');
    return res.data as List<dynamic>;
  }

  Future<void> addMessage(String conversationId, String role, String content,
      {int? tokensUsed}) async {
    await _dio.post('/api/chat/conversations/$conversationId/messages', data: {
      'role': role,
      'content': content,
      if (tokensUsed != null) 'tokensUsed': tokensUsed,
    });
  }

  Future<List<dynamic>> getModels() async {
    final res = await _dio.get('/api/chat/models');
    return res.data as List<dynamic>;
  }

  Future<void> updateConversation(String id,
      {String? title, bool? archived}) async {
    await _dio.patch('/api/chat/conversations/$id', data: {
      if (title != null) 'title': title,
      if (archived != null) 'archived': archived,
    });
  }

  Future<void> deleteConversation(String id) async {
    await _dio.delete('/api/chat/conversations/$id');
  }
}
