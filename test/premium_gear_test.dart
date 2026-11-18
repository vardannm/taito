import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'support/shop_navigation.dart';
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

  test('premium gear outprices all coin gear and is bought with coins', () {
    final balls = BallCosmetic.values.where((b) => b.purchaseOnly).toList();
    final platforms = PlatformStyle.values
        .where((p) => p.purchaseOnly)
        .toList();
    final topBall = BallCosmetic.values
        .where((b) => !b.purchaseOnly)
        .map((b) => b.cost)
        .reduce(math.max);
    final topPlatform = PlatformStyle.values
        .where((p) => !p.purchaseOnly)
        .map((p) => p.cost)
        .reduce(math.max);
    expect(balls.first.cost, greaterThan(topBall * 1.5));
    expect(platforms.first.cost, greaterThan(topPlatform * 2));
    for (var i = 1; i < balls.length; i++) {
      expect(balls[i].cost, greaterThan(balls[i - 1].cost));
      expect(platforms[i].cost, greaterThan(platforms[i - 1].cost));
    }
    final short = PlayerProfile()..wallet = BallCosmetic.aether.cost - 1;
    expect(short.selectBall(BallCosmetic.aether), isFalse);
    expect(short.ownedBalls.contains(BallCosmetic.aether), isFalse);
    final total = [
      ...balls.map((b) => b.cost),
      ...platforms.map((p) => p.cost),
    ].reduce((a, b) => a + b);
    final rich = PlayerProfile()..wallet = total;
    for (final ball in balls) {
      expect(rich.selectBall(ball), isTrue);
    }
    for (final platform in platforms) {
      expect(rich.selectPlatform(platform), isTrue);
    }
    expect(rich.wallet, 0);
    expect(rich.ownedBalls, containsAll(balls));
    expect(rich.ownedPlatforms, containsAll(platforms));
    expect(rich.selectedBall, BallCosmetic.genesis);
    expect(rich.selectedPlatform, PlatformStyle.genesis);
  });

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
    'premium cards show coin prices and buy when affordable on a small phone',
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
      await revealShopBall(tester, BallCosmetic.aether);
      await tester.pump();
      expect(find.text('Coming soon'), findsNothing);
      expect(find.text('25,000'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('buy-aether')));
      await tester.pump();
      expect(p.ownedBalls.contains(BallCosmetic.aether), isTrue);
      expect(p.selectedBall, BallCosmetic.aether);
      expect(p.wallet, 100000 - BallCosmetic.aether.cost);
      // Out of reach now: the price stays and the button waits.
      p.wallet = PlatformStyle.aether.cost - 1;
      await revealShopPlatform(tester, PlatformStyle.aether);
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
