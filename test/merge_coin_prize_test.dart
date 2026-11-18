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

  test(
    'coins spawn sparsely, scale with the head, and collect by swept contact',
    () {
      final run = MergeRun(seed: 7);
      expect(run.coins.length, 1);
      expect(run.coinValue, 1);
      run.segments[0] = 2048;
      expect(run.coinValue, 10);
      run.orbs.clear();
      run.coins
        ..clear()
        ..add(MergeCoin(180, 200, 7));
      run.step(.1, 100, 200, 260, 200);
      expect(run.coinsCollected, 7);
      expect(run.coins, isEmpty);
      run.step(.1, 260, 200, 100, 200);
      expect(run.coinsCollected, 7);
    },
  );

  test('fatal number contact prevents collecting coins behind it', () {
    final run = MergeRun(seed: 7);
    run.orbs
      ..clear()
      ..add(NumberOrb(140, 200, 4));
    run.coins
      ..clear()
      ..add(MergeCoin(220, 200, 3));
    run.step(.1, 100, 200, 260, 200);
    expect(run.ended, isTrue);
    expect(run.coinsCollected, 0);
  });

  test('coins expire below the road and are not collected by the tail', () {
    final run = MergeRun(seed: 7);
    run.orbs.clear();
    run.coins
      ..clear()
      ..add(MergeCoin(180, 600, 1))
      ..add(MergeCoin(180, 250, 1));
    run.step(.1, 180, 200, 180, 200);
    expect(run.coinsCollected, 0);
    expect(run.coins.length, 1);
  });

  test(
    'collected coins bank once, survive loss, persist and reset on retry',
    () async {
      final profile = PlayerProfile()..wallet = 73;
      final game = BalanceGame()..start(gameMode: GameMode.merge2048);
      game.mergeRun.highest = 2048;
      profile.recordResult(game);
      expect(profile.wallet, 73);
      game.coinsCollected = 7;
      game.phase = GamePhase.over;
      profile.recordResult(game);
      profile.recordResult(game);
      expect(profile.wallet, 80);
      expect(game.coinsCollected, 7);
      expect(profile.mergeRuns, 1);
      await profile.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.wallet, 80);

      game.start(gameMode: GameMode.merge2048);
      expect(game.coinsCollected, 0);
      game.mergeRun.highest = 4096;
      game.coinsCollected = 4;
      game.phase = GamePhase.over;
      restored.recordResult(game);
      restored.recordResult(game);
      expect(restored.wallet, 84);
      expect(game.coinsCollected, 4);
      await restored.save();
    },
  );

  test(
    'live Merge pickups pause, update the HUD count and bank below 2048',
    () async {
      final profile = PlayerProfile();
      final game = BalanceGame()..start(gameMode: GameMode.merge2048);
      game.mergeRun.orbs.clear();
      game.mergeRun.coins
        ..clear()
        ..add(MergeCoin(game.ballX, game.ballY, 3));
      game.setPaused(true);
      game.step(.01);
      expect(game.coinsCollected, 0);
      game.setPaused(false);
      game.step(.01);
      expect(game.coinsCollected, 3);
      expect(game.event, GameEvent.coin);
      expect(profile.bankCoins(game), isTrue);
      expect(profile.bankCoins(game), isFalse);
      expect(profile.wallet, 3);
      game.mergeRun.orbs.add(NumberOrb(game.ballX, game.ballY, 4));
      game.step(.01);
      expect(game.finished, isTrue);
      profile.recordResult(game);
      expect(profile.wallet, 3);
      await profile.save();
    },
  );

  test('reaching 2,048 without coins pays no flat prize', () async {
    final profile = PlayerProfile();
    final game = BalanceGame()..start(gameMode: GameMode.merge2048);
    game.mergeRun.highest = 2048;
    game.phase = GamePhase.over;
    profile.recordResult(game);
    expect(profile.wallet, 0);
    expect(game.coinsCollected, 0);
    await profile.save();
  });

  testWidgets(
    'Merge results show saved collectibles without a milestone claim',
    (tester) async {
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
      expect(
        find.text('+30 coins collected · Saved to wallet'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
