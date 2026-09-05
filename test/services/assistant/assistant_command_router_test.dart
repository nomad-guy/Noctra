import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noctra/core/theme/noir_theme.dart';
import 'package:noctra/services/assistant/application/assistant_command_router.dart';
import 'package:noctra/services/assistant/domain/assistant_command.dart';
import 'package:noctra/services/assistant/domain/assistant_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantCommandRouter Tests', () {
    late AssistantCommandRouter router;
    NoirThemeMode? changedTheme;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      router = AssistantCommandRouter(
        themeCallback: (mode) {
          changedTheme = mode;
        },
      );
    });

    test('dispatches ChangeThemeCommand to registered callback', () async {
      final result1 = await router.execute(const ChangeThemeCommand('noir_white'));
      expect(result1, isA<AssistantSuccess>());
      expect(changedTheme, equals(NoirThemeMode.noirWhite));

      final result2 = await router.execute(const ChangeThemeCommand('liquid_glass'));
      expect(result2, isA<AssistantSuccess>());
      expect(changedTheme, equals(NoirThemeMode.liquidGlass));

      final result3 = await router.execute(const ChangeThemeCommand('noir_black'));
      expect(result3, isA<AssistantSuccess>());
      expect(changedTheme, equals(NoirThemeMode.noirBlack));
    });

    test('rejects unknown theme mode with AssistantInvalidCommand', () async {
      final result = await router.execute(const ChangeThemeCommand('amoled_neon'));
      expect(result, isA<AssistantInvalidCommand>());
    });

    test('executes ClearQueueCommand safely', () async {
      final result = await router.execute(const ClearQueueCommand());
      expect(result, isA<AssistantSuccess>());
    });

    test('executes SetShuffleCommand safely', () async {
      final result = await router.execute(const SetShuffleCommand(true));
      expect(result, isA<AssistantSuccess>());
    });

    test('executes SetRepeatCommand with supported modes', () async {
      final result = await router.execute(const SetRepeatCommand('all'));
      expect(result, isA<AssistantSuccess>());
    });

    test('returns AssistantNotFound for non-existent playlist', () async {
      final result = await router.execute(const PlayPlaylistCommand('unreal_playlist_999'));
      expect(result, isA<AssistantNotFound>());
    });
  });
}
