import 'support/shop_actions.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/survival_upgrades.dart';
import 'magnet_test.dart' show cleanRun, tick;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'purchases charge coins, enforce limits, and survive reload and backup',
    () async {
      final p = PlayerProfile(unlimitedCoins: false);
      expect(p.buySurvivalUpgrade(SurvivalUpgrade.hearts), false);
      expect(p.startingHearts, 3);
      p.wallet = 10000;
      for (final upgrade in SurvivalUpgrade.values) {
        for (var i = 0; i < upgrade.maxLevel; i++) {
          final before = p.wallet;
          expect(p.buySurvivalUpgrade(upgrade), true);
          expect(p.wallet, before - upgrade.costAt(i));
        }
        final before = p.wallet;
        expect(p.buySurvivalUpgrade(upgrade), false);
        expect(p.wallet, before);
      }
      await p.saveEconomy();
      final loaded = PlayerProfile(unlimitedCoins: false);
      await loaded.load();
      expect(loaded.startingHearts, 6);
      expect(loaded.magnetDuration, 20);
      expect(loaded.shieldDuration, 18);
      final backup = ProgressBackup.decode(
        ProgressBackup.encode(loaded),
        testEconomy: false,
      );
      expect(backup.survivalUpgrades, loaded.survivalUpgrades);
      final restored = PlayerProfile(unlimitedCoins: false);
      await ProgressBackup.restore(restored, backup);
      expect(restored.startingHearts, 6);
      final legacy =
          jsonDecode(ProgressBackup.encode(loaded)) as Map<String, dynamic>;
      legacy.remove('survivalUpgrades');
      final old = ProgressBackup.decode(jsonEncode(legacy), testEconomy: false);
      expect(old.startingHearts, 3);
      expect(old.magnetDuration, InfiniteTuning.magnetSeconds);
      expect(old.shieldDuration, InfiniteTuning.shieldSeconds);
    },
  );

  test(
    'Infinite starts with bought hearts and pickups use upgraded durations and life cap',
    () {
      final p = PlayerProfile(unlimitedCoins: true);
      for (final upgrade in SurvivalUpgrade.values) {
        for (var i = 0; i < upgrade.maxLevel; i++) {
          p.buySurvivalUpgrade(upgrade);
        }
      }
      final g = BalanceGame(seed: 7);
      p.applySurvivalUpgrades(g);
      g.start(gameMode: GameMode.infinite);
      expect(g.lives, 6);
      g.start(gameMode: GameMode.classic);
      expect(g.lives, 3);
      final run = cleanRun();
      p.applySurvivalUpgrades(run);
      run.lives = 5;
      run.survival.items.addAll([
        InfiniteItem(InfiniteItemKind.shield, run.ballX, run.ballY),
        InfiniteItem(InfiniteItemKind.magnet, run.ballX, run.ballY),
        InfiniteItem(InfiniteItemKind.heart, run.ballX, run.ballY),
      ]);
      tick(run);
      expect(run.survival.shield, closeTo(18, .02));
      expect(run.survival.magnet, closeTo(20, .02));
      expect(run.lives, 6);
      run.survival.items.add(
        InfiniteItem(InfiniteItemKind.heart, run.ballX, run.ballY),
      );
      tick(run);
      expect(run.lives, 6);
      expect(p.wallet, 0);
    },
  );

  testWidgets(
    'shop purchases show new value and disable unaffordable next tier',
    (tester) async {
      final p = PlayerProfile(unlimitedCoins: false)..wallet = 150;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BallShop(profile: p)),
        ),
      );
      await tester.tap(find.text('Upgrades'));
      await tester.pump();
      final buy = find.byKey(const ValueKey('upgrade-magnet'));
      await tester.scrollUntilVisible(
        buy.hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(buy);
      await completeShopPurchase(tester);
      await tester.pump();
      expect(p.magnetDuration, 11);
      expect(p.wallet, 0);
      expect(find.text('Current: 11 seconds'), findsOneWidget);
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await p.saveEconomy();
    },
  );
}
