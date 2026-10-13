import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'new balls follow Black Hole and stronger platforms follow Sovereign',
    () {
      final balls = BallCosmetic.values.where((b) => b.purchaseOnly).toList();
      final platforms = PlatformStyle.values
          .where((p) => p.purchaseOnly)
          .toList();
      expect(balls.length, 4);
      expect(platforms.length, 4);
      expect(balls.first.index, BallCosmetic.singularity.index + 1);
      expect(platforms.first.index, PlatformStyle.sovereign.index + 1);
      for (var i = 0; i < balls.length; i++) {
        final previous = i == 0 ? BallCosmetic.singularity : balls[i - 1];
        expect(balls[i].scoreBonus, greaterThan(previous.scoreBonus));
        expect(balls[i].magnetRadius, greaterThan(previous.magnetRadius));
        final rail = i == 0 ? PlatformStyle.sovereign : platforms[i - 1];
        expect(platforms[i].scoreBonus, greaterThan(rail.scoreBonus));
      }
      final game = BalanceGame()
        ..cosmetic = BallCosmetic.genesis
        ..platformStyle = PlatformStyle.genesis;
      expect(game.equipmentMultiplier, 12.5);
      expect(BallCosmetic.genesis.magnetRadius, 120);
    },
  );

  test(
    'coin balances and unlimited-coin mode cannot unlock reserved premium gear',
    () async {
      for (final unlimited in [false, true]) {
        final profile = PlayerProfile(unlimitedCoins: unlimited)
          ..wallet = 100000;
        for (final ball in BallCosmetic.values.where((b) => b.purchaseOnly)) {
          expect(profile.selectBall(ball), isFalse);
          expect(profile.ownedBalls.contains(ball), isFalse);
        }
        for (final platform in PlatformStyle.values.where(
          (p) => p.purchaseOnly,
        )) {
          expect(profile.selectPlatform(platform), isFalse);
          expect(profile.ownedPlatforms.contains(platform), isFalse);
        }
        expect(profile.wallet, 100000);
        expect(profile.selectedBall, BallCosmetic.steel);
        expect(profile.selectedPlatform, PlatformStyle.classic);
      }
    },
  );

  test(
    'daily gifts skip premium gear even when every coin item is owned',
    () async {
      final p = PlayerProfile()
        ..ownedBalls.addAll(BallCosmetic.values.where((b) => !b.purchaseOnly))
        ..ownedPlatforms.addAll(
          PlatformStyle.values.where((b) => !b.purchaseOnly),
        );
      expect(p.prizeBall, isNull);
      expect(p.prizePlatform, isNull);
      for (var day = 1; day <= 5; day++)
        await p.claimDailyPrize(now: DateTime.utc(2026, 10, day));
      expect(p.wallet, 170);
      expect(p.ownedBalls.any((b) => b.purchaseOnly), isFalse);
      expect(p.ownedPlatforms.any((b) => b.purchaseOnly), isFalse);
    },
  );

  test('an owned premium entitlement equips and survives reload', () async {
    final p = PlayerProfile()..wallet = 50;
    // Represents a future verified purchase; the coin-buy path cannot grant it.
    p.ownedBalls.add(BallCosmetic.genesis);
    p.ownedPlatforms.add(PlatformStyle.genesis);
    expect(p.selectBall(BallCosmetic.genesis), isTrue);
    expect(p.selectPlatform(PlatformStyle.genesis), isTrue);
    await p.saveEconomy();
    final loaded = PlayerProfile();
    await loaded.load();
    expect(loaded.selectedBall, BallCosmetic.genesis);
    expect(loaded.selectedPlatform, PlatformStyle.genesis);
    expect(loaded.wallet, 50);
    expect(loaded.equipmentMultiplier, 12.5);
  });

  testWidgets(
    'premium cards show disabled Coming soon actions on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..wallet = 100000;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BallShop(profile: p)),
        ),
      );
      final scroll = find
          .descendant(
            of: find.byType(BallShop),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-aether')),
        240,
        scrollable: scroll,
        maxScrolls: 100,
      );
      await tester.pump();
      expect(find.text('Coming soon'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-aether')))
            .onPressed,
        isNull,
      );
      expect(p.ownedBalls.contains(BallCosmetic.aether), isFalse);
      await tester.tap(find.text('Platforms'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-platform-aether')),
        240,
        scrollable: find
            .descendant(
              of: find.byType(BallShop),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 100,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('buy-platform-aether')),
            )
            .onPressed,
        isNull,
      );
      expect(p.ownedPlatforms.contains(PlatformStyle.aether), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
