import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/coin_store.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/shop_navigation.dart';

// The shop's artwork animates forever, so pump a fixed span instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  Future<PlayerProfile> openShop(WidgetTester tester, {int wallet = 0}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..wallet = wallet;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: p)),
      ),
    );
    await tester.pump();
    return p;
  }

  test('packs grow in coins and value, and cover every premium ball', () {
    for (var i = 1; i < coinPacks.length; i++) {
      expect(coinPacks[i].coins, greaterThan(coinPacks[i - 1].coins));
      expect(coinPacks[i].bonus, greaterThan(coinPacks[i - 1].bonus));
    }
    expect(coinPacks.map((p) => p.id).toSet().length, coinPacks.length);
    expect(coinPacks.last.coins, greaterThan(BallCosmetic.genesis.cost));
  });

  testWidgets('launch build hides every way into the coin store', (
    tester,
  ) async {
    expect(coinStoreVisible, isFalse);
    final p = await openShop(tester, wallet: 50);
    expect(find.byTooltip('Get coins'), findsNothing);
    await revealShopBall(tester, BallCosmetic.coral);
    expect(find.text('Need 10 more coins'), findsOneWidget);
    expect(find.textContaining('Get coins'), findsNothing);
    expect(find.byType(CoinStoreSheet), findsNothing);
    expect(p.wallet, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hidden sheet still charges nothing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()..wallet = 1234;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CoinStoreSheet(profile: p, needed: 10)),
      ),
    );
    await settle(tester);
    expect(find.text('COVERS THIS ITEM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coin-pack-coins_30000')));
    await settle(tester);
    expect(find.byKey(const ValueKey('coin-store-notice')), findsOneWidget);
    expect(p.wallet, 1234);
    expect(tester.takeException(), isNull);
  });
}
