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
      final p = PlayerProfile()..wallet = 34;
      expect(p.shopUpgradeAvailable, isFalse);
      p.wallet = 35;
      expect(p.shopUpgradeAvailable, isTrue);
      p.selectBall(BallCosmetic.coral);
      expect(p.wallet, 0);
      expect(p.shopUpgradeAvailable, isFalse);
      p.wallet = 35;
      expect(p.shopUpgradeAvailable, isFalse); // Already owned.
      p.wallet = 65;
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
    p.wallet = 100000;
    expect(p.shopUpgradeAvailable, isFalse); // No coin-purchasable improvement.
    p.ownedBalls.remove(BallCosmetic.singularity);
    p.ownedBalls.add(BallCosmetic.nova);
    p.wallet = BallCosmetic.titanium.cost;
    expect(p.shopUpgradeAvailable, isTrue); // Adds permanent magnet reach.
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
      ..wallet = 35;
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
