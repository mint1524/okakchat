import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:okakchat/core/api/chat_api.dart';
import 'package:okakchat/features/chat/chat_provider.dart';
import 'package:okakchat/main.dart';

class _FakeChatApi extends ChatApi {
  _FakeChatApi() : super(Dio());

  @override
  Future<List<dynamic>> getModels() async => const [];
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatApiProvider.overrideWithValue(_FakeChatApi()),
        ],
        child: const OkakChatApp(),
      ),
    );
    await tester.pump();
  });
}
