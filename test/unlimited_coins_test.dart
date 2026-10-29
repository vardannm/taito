import 'support/shop_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/shop_design.dart';
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
    'unlimited purchases survive reload without changing normal economy',
    () async {
      final normal = PlayerProfile(unlimitedCoins: false)..wallet = 100;
      expect(normal.selectBall(BallCosmetic.coral), isTrue);
      await normal.saveEconomy();
      final testing = PlayerProfile(unlimitedCoins: true);
      await testing.load();
      for (final ball in BallCosmetic.values.where((b) => !b.purchaseOnly)) {
        expect(testing.selectBall(ball), isTrue);
      }
      for (final platform in PlatformStyle.values.where(
        (p) => !p.purchaseOnly,
      )) {
        expect(testing.selectPlatform(platform), isTrue);
      }
      expect(testing.wallet, 0);
      await testing.saveEconomy();
      final reloaded = PlayerProfile(unlimitedCoins: true);
      await reloaded.load();
      expect(
        reloaded.ownedBalls,
        containsAll(BallCosmetic.values.where((b) => !b.purchaseOnly)),
      );
      expect(
        reloaded.ownedPlatforms,
        containsAll(PlatformStyle.values.where((p) => !p.purchaseOnly)),
      );
      final original = PlayerProfile(unlimitedCoins: false);
      await original.load();
      expect(original.wallet, 100 - BallCosmetic.coral.cost);
      expect(original.ownedPlatforms, {PlatformStyle.classic});
      expect(original.selectedBall, BallCosmetic.coral);
      expect(original.canAfford(10000), isFalse);
    },
  );

  test('fresh profiles stay at zero coins across saves and reloads', () async {
    final profile = PlayerProfile();
    await profile.load();
    expect(profile.wallet, 0);
    expect(profile.selectBall(BallCosmetic.coral), isFalse);
    await profile.saveEconomy();
    final reloaded = PlayerProfile();
    await reloaded.load();
    expect(reloaded.wallet, 0);
  });

  test('normal profiles never enable unlimited coins from build flags', () {
    expect(PlayerProfile().unlimitedCoins, isFalse);
  });

  test(
    'saved coins and purchased gear survive reload without launch credits',
    () async {
      final profile = PlayerProfile()..wallet = 100;
      expect(profile.selectBall(BallCosmetic.coral), isTrue);
      await profile.saveEconomy();
      final reloaded = PlayerProfile();
      await reloaded.load();
      expect(reloaded.wallet, 100 - BallCosmetic.coral.cost);
      expect(reloaded.ownedBalls, contains(BallCosmetic.coral));
    },
  );

  testWidgets('zero-wallet test shop enables buying platforms', (tester) async {
    final profile = PlayerProfile(unlimitedCoins: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: profile)),
      ),
    );
    // The wallet shows the endless mark; gear cards show it beside boosts.
    expect(
      find
          .text('\u221e')
          .evaluate()
          .where(
            (e) => e.findAncestorWidgetOfExactType<ShopBoostChip>() == null,
          ),
      hasLength(1),
    );
    await tester.tap(find.text('Platforms'));
    await tester.pump();
    final buy = find.byKey(const ValueKey('buy-platform-copper'));
    await tester.scrollUntilVisible(
      buy.hitTestable(),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(buy);
    await completeShopPurchase(tester);
    await tester.pump();
    expect(profile.selectedPlatform, PlatformStyle.copper);
    expect(profile.wallet, 0);
    await profile.saveEconomy();
  });
}
