import 'support/shop_actions.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/survival_upgrades.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'hint starts at the exact affordable price and clears after purchase',
    () {
      final p = PlayerProfile()..wallet = BallCosmetic.coral.cost - 1;
      expect(p.shopUpgradeAvailable, isFalse);
      p.wallet = BallCosmetic.coral.cost;
      expect(p.shopUpgradeAvailable, isTrue);
      p.selectBall(BallCosmetic.coral);
      expect(p.wallet, 0);
      expect(p.shopUpgradeAvailable, isFalse);
      p.wallet = BallCosmetic.coral.cost;
      expect(p.shopUpgradeAvailable, isFalse); // Already owned.
      p.wallet = BallCosmetic.circuit.cost;
      expect(p.shopUpgradeAvailable, isTrue);
    },
  );

  test('platforms, magnets and non-maxed upgrades each qualify', () {
    final p = PlayerProfile()..wallet = 80;
    p.ownedBalls.add(BallCosmetic.singularity);
    expect(p.shopUpgradeAvailable, isTrue); // Copperline platform.
    p.ownedPlatforms.add(PlatformStyle.sovereign);
    expect(p.shopUpgradeAvailable, isFalse); // Weaker gear is cosmetic only.
    p.wallet = 150;
    expect(p.shopUpgradeAvailable, isTrue); // Duration upgrade.
    for (final upgrade in SurvivalUpgrade.values) {
      p.survivalUpgrades[upgrade] = upgrade.maxLevel;
    }
    p.wallet = PlatformStyle.aether.cost - 1;
    expect(p.shopUpgradeAvailable, isFalse); // Premium gear is out of reach.
    p.wallet = PlatformStyle.aether.cost;
    expect(p.shopUpgradeAvailable, isTrue); // Premium gear sells for coins.
    p.ownedBalls.remove(BallCosmetic.singularity);
    p.ownedBalls.add(BallCosmetic.nova);
    p.wallet = BallCosmetic.titanium.cost;
    // Titanium is cheaper than the owned Nova: never suggest a step back.
    expect(p.shopUpgradeAvailable, isFalse);
    p.wallet = BallCosmetic.eclipse.cost;
    expect(p.shopUpgradeAvailable, isTrue); // The next ball up the price list.
  });

  test('skipping ahead hides every cheaper ball and platform', () {
    final p = PlayerProfile()..wallet = 0;
    for (final upgrade in SurvivalUpgrade.values) {
      p.survivalUpgrades[upgrade] = upgrade.maxLevel;
    }
    // Bought the fifth ball and fourth rail without the earlier ones.
    p.ownedBalls.add(ballShopOrder[4]);
    p.ownedPlatforms.add(platformShopOrder[3]);
    p.wallet = ballShopOrder[4].cost - 1;
    expect(p.shopUpgradeAvailable, isFalse);
    p.wallet = ballShopOrder[5].cost;
    expect(p.shopUpgradeAvailable, isTrue);
    p.ownedBalls.add(ballShopOrder.lastWhere((b) => !b.purchaseOnly));
    p.wallet = platformShopOrder[4].cost - 1;
    expect(p.shopUpgradeAvailable, isFalse);
    p.wallet = platformShopOrder[4].cost;
    expect(p.shopUpgradeAvailable, isTrue);
  });

  test('shop lists gear by price, premium gear last', () {
    void check<T>(
      List<T> order,
      int Function(T) cost,
      bool Function(T) premium,
    ) {
      final standard = order.where((e) => !premium(e)).toList();
      expect(order.take(standard.length), standard);
      for (var i = 1; i < order.length; i++) {
        expect(cost(order[i]), greaterThanOrEqualTo(cost(order[i - 1])));
      }
    }

    check(ballShopOrder, (b) => b.cost, (b) => b.purchaseOnly);
    check(platformShopOrder, (p) => p.cost, (p) => p.purchaseOnly);
    expect(ballShopOrder.toSet(), BallCosmetic.values.toSet());
    expect(platformShopOrder.toSet(), PlatformStyle.values.toSet());
  });

  testWidgets('shop dot clears on return and collection has three tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..wallet = BallCosmetic.coral.cost;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('shop-upgrade-hint')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('board-shop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cabinet Styles'), findsNothing);
    for (final tab in ['Balls', 'Platforms', 'Upgrades']) {
      expect(find.text(tab), findsOneWidget);
    }
    final buy = find.byKey(const ValueKey('buy-coral'));
    await tester.scrollUntilVisible(
      buy.hitTestable(),
      180,
      scrollable: find
          .descendant(
            of: find.byType(BallShop),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(buy);
    await completeShopPurchase(tester);
    await tester.pump();
    expect(p.wallet, 0);
    await tester.tap(find.byTooltip('Done shopping'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('shop-upgrade-hint')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
