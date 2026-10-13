import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewarded_revive_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'infinite_revive_test.dart'
    show FakeReviveAds, launchRevive, loseLastHeart;
import 'support/mode_navigation.dart';

void main() {
  late PlayerProfile profile;
  late FakeReviveAds ads;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    profile = PlayerProfile(unlimitedCoins: false)
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..controlMode = ControlMode.oneFinger
      ..wallet = 100;
    ads = FakeReviveAds();
  });

  test(
    'doubling requires a lost Infinite run with strictly more than 10 coins',
    () {
      for (final mode in GameMode.values) {
        final game = BalanceGame()..start(gameMode: mode);
        game.coinsCollected = 11;
        expect(profile.canDoubleInfiniteCoins(game), isFalse);
        game.lives = 0;
        game.phase = GamePhase.over;
        expect(profile.canDoubleInfiniteCoins(game), mode == GameMode.infinite);
      }
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      game.lives = 0;
      game.phase = GamePhase.over;
      for (final coins in [0, 10, 11]) {
        game.coinsCollected = coins;
        expect(profile.canDoubleInfiniteCoins(game), coins > 10);
      }
      game.won = true;
      expect(profile.canDoubleInfiniteCoins(game), isFalse);
    },
  );

  test(
    'bonus doubles only run coins, banks once, and persists without changing the ledger',
    () async {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      game.coinsCollected = 12;
      profile.bankCoins(game);
      expect(profile.wallet, 112);
      game.lives = 0;
      game.phase = GamePhase.over;
      expect(profile.doubleInfiniteCoins(game), isTrue);
      expect(profile.wallet, 124);
      expect(game.coinsCollected, 12);
      expect(profile.doubleInfiniteCoins(game), isFalse);
      expect(profile.bankCoins(game), isFalse);
      await profile.saveEconomy();
      final reloaded = PlayerProfile(unlimitedCoins: false);
      await reloaded.load();
      expect(reloaded.wallet, 124);
    },
  );

  for (final coins in [10, 11]) {
    testWidgets(
      'game over offers doubling for $coins collected coins only above threshold',
      (tester) async {
        final game = await launchRevive(tester, profile, ads);
        game.coins.clear();
        game.coinsCollected = coins;
        await loseLastHeart(tester, game);
        expect(
          find.byKey(const ValueKey('coin-double-offer')),
          coins > 10 ? findsOneWidget : findsNothing,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('decline-revive')),
        );
        await tester.tap(find.byKey(const ValueKey('decline-revive')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('coin-double-offer')),
          coins > 10 ? findsOneWidget : findsNothing,
        );
        expect(profile.wallet, 100 + coins);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'doubling from the revive screen ends the run and pays only after reward once',
    (tester) async {
      final game = await launchRevive(tester, profile, ads);
      game.coins.clear();
      game.coinsCollected = 12;
      await loseLastHeart(tester, game);
      await tester.ensureVisible(
        find.byKey(const ValueKey('watch-coin-double-ad')),
      );
      await tester.tap(find.byKey(const ValueKey('watch-coin-double-ad')));
      await tester.pump();
      expect(find.byKey(const ValueKey('revive-offer')), findsNothing);
      expect(profile.infiniteRuns, 1);
      expect(profile.wallet, 112);
      final dynamic state = tester.state(find.byType(GameScreen));
      state.watchCoinDoubleAd();
      state.start(GameMode.infinite);
      expect(ads.calls, 1);
      expect(game.finished, isTrue);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'ONE MORE RUN'),
            )
            .onPressed,
        isNull,
      );
      ads.pending!.complete(ReviveAdResult.earned);
      await tester.pump();
      expect(profile.wallet, 124);
      expect(game.finished, isTrue);
      expect(game.lives, 0);
      expect(find.byKey(const ValueKey('coins-doubled')), findsOneWidget);
      expect(find.byKey(const ValueKey('coin-double-offer')), findsNothing);
      state.watchCoinDoubleAd();
      expect(ads.calls, 1);
      expect(profile.infiniteRuns, 1);
      await tester.pumpWidget(const SizedBox());
      expect(profile.wallet, 124);
      expect(tester.takeException(), isNull);
    },
  );

  for (final result in [ReviveAdResult.dismissed, ReviveAdResult.unavailable]) {
    testWidgets('$result preserves coins and permits retrying the bonus ad', (
      tester,
    ) async {
      final game = await launchRevive(tester, profile, ads);
      game.coins.clear();
      game.coinsCollected = 11;
      await loseLastHeart(tester, game);
      await tester.ensureVisible(
        find.byKey(const ValueKey('watch-coin-double-ad')),
      );
      await tester.tap(find.byKey(const ValueKey('watch-coin-double-ad')));
      await tester.pump();
      ads.pending!.complete(result);
      await tester.pump();
      expect(profile.wallet, 111);
      expect(game.lives, 0);
      expect(find.byKey(const ValueKey('coin-double-offer')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('watch-coin-double-ad')),
      );
      await tester.tap(find.byKey(const ValueKey('watch-coin-double-ad')));
      await tester.pump();
      expect(ads.calls, 2);
      ads.pending!.complete(ReviveAdResult.earned);
      await tester.pump();
      expect(profile.wallet, 122);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'revived runs can double their final coins and new runs get their own bonus',
    (tester) async {
      final game = await launchRevive(tester, profile, ads);
      game.coins.clear();
      game.coinsCollected = 11;
      await loseLastHeart(tester, game);
      await tester.ensureVisible(find.byKey(const ValueKey('watch-revive-ad')));
      await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
      await tester.pump();
      ads.pending!.complete(ReviveAdResult.earned);
      await tester.pump();
      expect(game.finished, isFalse);
      game.coinsCollected = 15;
      await loseLastHeart(tester, game);
      await tester.ensureVisible(
        find.byKey(const ValueKey('watch-coin-double-ad')),
      );
      await tester.tap(find.byKey(const ValueKey('watch-coin-double-ad')));
      await tester.pump();
      ads.pending!.complete(ReviveAdResult.earned);
      await tester.pump();
      expect(profile.wallet, 130);
      final dynamic state = tester.state(find.byType(GameScreen));
      state.start(GameMode.infinite);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await startWorld(tester);
      game.coins.clear();
      game.coinsCollected = 11;
      await loseLastHeart(tester, game);
      expect(find.byKey(const ValueKey('coin-double-offer')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late reward after disposal cannot credit a coin bonus', (
    tester,
  ) async {
    final game = await launchRevive(tester, profile, ads);
    game.coins.clear();
    game.coinsCollected = 11;
    await loseLastHeart(tester, game);
    await tester.ensureVisible(
      find.byKey(const ValueKey('watch-coin-double-ad')),
    );
    await tester.tap(find.byKey(const ValueKey('watch-coin-double-ad')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    ads.pending!.complete(ReviveAdResult.earned);
    await tester.pump();
    expect(profile.wallet, 111);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported platforms retain coins without an ad offer', (
    tester,
  ) async {
    ads.supported = false;
    final game = await launchRevive(tester, profile, ads);
    game.coins.clear();
    game.coinsCollected = 11;
    await loseLastHeart(tester, game);
    expect(find.byKey(const ValueKey('coin-double-offer')), findsNothing);
    expect(profile.wallet, 111);
    expect(ads.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
