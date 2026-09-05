import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctra/services/assistant/application/assistant_command_router.dart';
import 'package:noctra/services/assistant/domain/assistant_command.dart';
import 'package:noctra/services/assistant/domain/assistant_result.dart';
import 'package:noctra/services/assistant/infrastructure/assistant_intent_channel.dart';

class MockAssistantRouter extends AssistantCommandRouter {
  AssistantCommand? lastExecutedCommand;

  @override
  Future<AssistantResult> execute(AssistantCommand command) async {
    lastExecutedCommand = command;
    return const AssistantSuccess(null, 'Executed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantIntentChannel Tests', () {
    const channel = MethodChannel('com.nomadguy.noctra/assistant_intent');
    late MockAssistantRouter mockRouter;
    late AssistantIntentChannel intentChannel;

    setUp(() {
      mockRouter = MockAssistantRouter();
      intentChannel = AssistantIntentChannel(router: mockRouter);
      intentChannel.initialize();
    });

    tearDown(() {
      intentChannel.dispose();
    });

    test('routes search query from intent payload', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('onMediaPlayFromSearch', {'query': 'Thamma Thamma'}),
        ),
        (_) {},
      );

      expect(mockRouter.lastExecutedCommand, isA<SearchAndPlayCommand>());
      final cmd = mockRouter.lastExecutedCommand as SearchAndPlayCommand;
      expect(cmd.query, equals('Thamma Thamma'));
    });

    test('routes noctra://track deep link to PlayTrackCommand', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('onViewIntent', {'data': 'noctra://track/test_id_123'}),
        ),
        (_) {},
      );

      expect(mockRouter.lastExecutedCommand, isA<PlayTrackCommand>());
      final cmd = mockRouter.lastExecutedCommand as PlayTrackCommand;
      expect(cmd.trackId, equals('test_id_123'));
    });

    test('routes noctra://search deep link to SearchAndPlayCommand', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('onViewIntent', {'data': 'noctra://search?q=Believer'}),
        ),
        (_) {},
      );

      expect(mockRouter.lastExecutedCommand, isA<SearchAndPlayCommand>());
      final cmd = mockRouter.lastExecutedCommand as SearchAndPlayCommand;
      expect(cmd.query, equals('Believer'));
    });

    test('routes noctra://playlist deep link to PlayPlaylistCommand', () async {
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('onViewIntent', {'data': 'noctra://playlist/Rock%20Classics'}),
        ),
        (_) {},
      );

      expect(mockRouter.lastExecutedCommand, isA<PlayPlaylistCommand>());
      final cmd = mockRouter.lastExecutedCommand as PlayPlaylistCommand;
      expect(cmd.playlistIdOrName, equals('Rock Classics'));
    });
  });
}
