import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/merge.dart';
import 'package:balance_arcade/merge_widgets.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('2,048 pays 30 coins once per finished run and persists', () async {
    final profile = PlayerProfile()..wallet = 73;
    final game = BalanceGame()..start(gameMode: GameMode.merge2048);
    game.mergeRun.highest = 2048;
    profile.recordResult(game);
    expect(profile.wallet, 73);
    game.phase = GamePhase.over;
    profile.recordResult(game);
    profile.recordResult(game);
    expect(profile.wallet, 103);
    expect(game.coinsCollected, 30);
    expect(profile.mergeRuns, 1);
    await profile.save();
    final restored = PlayerProfile();
    await restored.load();
    expect(restored.wallet, 103);

    game.start(gameMode: GameMode.merge2048);
    expect(game.coinsCollected, 0);
    game.mergeRun.highest = 4096;
    game.phase = GamePhase.over;
    restored.recordResult(game);
    restored.recordResult(game);
    expect(restored.wallet, 133);
    expect(game.coinsCollected, 30);
    await restored.save();
  });

  test('a Merge run below 2,048 receives no coin prize', () async {
    final profile = PlayerProfile();
    final game = BalanceGame()..start(gameMode: GameMode.merge2048);
    game.mergeRun.highest = 1024;
    game.phase = GamePhase.over;
    profile.recordResult(game);
    expect(profile.wallet, 0);
    expect(game.coinsCollected, 0);
    await profile.save();
  });

  testWidgets('Merge results show the banked 30 coin prize', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MergeResult(
            run: MergeRun()..highest = 2048,
            newBest: false,
            coinsEarned: 30,
            onRetry: () {},
            onHome: () {},
          ),
        ),
      ),
    );
    expect(find.text('+30 coins · 2,048 reached'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
