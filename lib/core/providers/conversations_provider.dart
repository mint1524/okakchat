import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

final conversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ChatApi(ref.watch(dioProvider));
  final list = await api.getConversations();
  return list.cast<Map<String, dynamic>>();
});
