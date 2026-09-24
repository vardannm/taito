import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
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
      for (final ball in BallCosmetic.values) {
        expect(testing.selectBall(ball), isTrue);
      }
      for (final platform in PlatformStyle.values) {
        expect(testing.selectPlatform(platform), isTrue);
      }
      expect(testing.wallet, 0);
      await testing.saveEconomy();
      final reloaded = PlayerProfile(unlimitedCoins: true);
      await reloaded.load();
      expect(reloaded.ownedBalls, containsAll(BallCosmetic.values));
      expect(reloaded.ownedPlatforms, containsAll(PlatformStyle.values));
      final original = PlayerProfile(unlimitedCoins: false);
      await original.load();
      expect(original.wallet, 100 - BallCosmetic.coral.cost);
      expect(original.ownedPlatforms, {PlatformStyle.classic});
      expect(original.selectedBall, BallCosmetic.coral);
      expect(original.canAfford(10000), isFalse);
    },
  );

  test('build flag selects the expected coin mode', () {
    expect(
      PlayerProfile().unlimitedCoins,
      const bool.fromEnvironment('GILT_UNLIMITED_COINS'),
    );
  });

  test(
    '10,000 test coins are added once and spent purchases survive restart',
    () async {
      final profile = PlayerProfile(unlimitedCoins: false)..wallet = 42;
      await profile.saveEconomy();
      await profile.grantBallTestCoins();
      expect(profile.wallet, 10042);
      expect(profile.selectBall(BallCosmetic.singularity), isTrue);
      await profile.saveEconomy();
      final reloaded = PlayerProfile(unlimitedCoins: false);
      await reloaded.load();
      await reloaded.grantBallTestCoins();
      expect(reloaded.wallet, 10042 - BallCosmetic.singularity.cost);
      expect(reloaded.ownedBalls, contains(BallCosmetic.singularity));
    },
  );

  testWidgets('zero-wallet test shop enables buying platforms', (tester) async {
    final profile = PlayerProfile(unlimitedCoins: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: profile)),
      ),
    );
    expect(find.text('TEST BUILD - Unlimited coins'), findsOneWidget);
    expect(find.text('\u221e'), findsOneWidget);
    await tester.tap(find.text('Platforms'));
    await tester.pump();
    final buy = find.byKey(const ValueKey('buy-platform-copper'));
    await tester.scrollUntilVisible(buy.hitTestable(), 150);
    await tester.tap(buy);
    await tester.pump();
    expect(profile.selectedPlatform, PlatformStyle.copper);
    expect(profile.wallet, 0);
    await profile.saveEconomy();
  });
}
