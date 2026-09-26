import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch;
import 'support/mode_navigation.dart';

List<double> layout(BalanceGame game) => [
  for (final hole in game.board) ...[hole.x, hole.y],
  for (final coin in game.coins) ...[coin.x, coin.y],
];

void main() {
  test('preview is stable and does not consume real run randomness', () {
    final game = BalanceGame(seed: 42);
    final direct = BalanceGame(seed: 42)..start(gameMode: GameMode.infinite);
    game.start(gameMode: GameMode.infinite, waitForInput: true);
    final preview = layout(game);
    final baked = BalanceGame(seed: 711)
      ..start(gameMode: GameMode.infinite);
    expect(preview, layout(baked));
    for (var i = 0; i < 5; i++) {
      game.start(gameMode: GameMode.classic, waitForInput: true);
      game.start(gameMode: GameMode.infinite, waitForInput: true);
      expect(layout(game), preview);
    }
    // Use a fresh model to compare direct launch with waiting then starting.
    final waiting = BalanceGame(seed: 42)
      ..start(gameMode: GameMode.infinite, waitForInput: true);
    for (var i = 0; i < 5; i++) {
      waiting.start(gameMode: GameMode.infinite, waitForInput: true);
    }
    final epoch = waiting.inputEpoch;
    final serial = waiting.runSerial;
    waiting.beginInput();
    expect(layout(waiting), layout(direct));
    expect(layout(waiting), isNot(preview));
    expect(waiting.inputEpoch, epoch);
    expect(waiting.runSerial, serial);
    final firstRun = layout(waiting);
    waiting.beginInput();
    expect(layout(waiting), firstRun);
    waiting.start(gameMode: GameMode.infinite, waitForInput: true);
    expect(layout(waiting), preview);
    waiting.beginInput();
    expect(layout(waiting), isNot(firstRun));
  });

  testWidgets('returning from every carousel world restores Infinite preview', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final game = await launch(tester, ControlMode.oneFinger);
    final preview = layout(game);
    for (final index in [1, 2, 3, 1]) {
      await selectWorld(tester, index);
      await selectWorld(tester, 0);
      expect(game.waitingForInput, isTrue);
      expect(layout(game), preview);
      expect(game.elapsed, 0);
    }
  });
}
