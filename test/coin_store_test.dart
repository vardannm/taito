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

  testWidgets('the wallet opens the coin store; packs charge nothing yet', (
    tester,
  ) async {
    final p = await openShop(tester, wallet: 1234);
    await tester.tap(find.byTooltip('Get coins'));
    await settle(tester);
    expect(find.text('Get coins'), findsWidgets);
    expect(find.byKey(const ValueKey('coin-store-wallet')), findsOneWidget);
    expect(find.text('1,234'), findsWidgets);
    expect(find.byKey(const ValueKey('coin-store-notice')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('coin-pack-coins_30000')));
    await settle(tester);
    expect(find.byKey(const ValueKey('coin-store-notice')), findsOneWidget);
    expect(find.textContaining('Nothing was charged'), findsOneWidget);
    expect(p.wallet, 1234);
    await tester.tap(find.byTooltip('Close coin store'));
    await settle(tester);
    expect(find.byType(CoinStoreSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unaffordable gear links to the pack that covers it', (
    tester,
  ) async {
    final p = await openShop(tester, wallet: 50);
    // Coral costs 60: the first card the player cannot afford.
    final link = find.byKey(const ValueKey('get-coins-buy-coral'));
    await revealShopBall(tester, BallCosmetic.coral);
    expect(find.text('Need 10 more · Get coins'), findsOneWidget);
    // Owned gear never offers coins.
    expect(find.byKey(const ValueKey('get-coins-buy-steel')), findsNothing);
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(
      find.descendant(of: link, matching: find.byType(TextButton)),
    );
    await settle(tester);
    expect(find.byType(CoinStoreSheet), findsOneWidget);
    expect(find.text('COVERS THIS ITEM'), findsOneWidget);
    expect(find.text('Need 10'), findsOneWidget);
    expect(p.wallet, 50);
    expect(tester.takeException(), isNull);
  });
}
