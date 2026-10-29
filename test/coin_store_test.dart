import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/coin_store.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets(
    'wallet opens real earning options and exposes no fake checkout',
    (tester) async {
      final p = await openShop(tester, wallet: 1234);
      await tester.tap(find.byTooltip('Get coins'));
      await settle(tester);
      expect(find.text('Earn coins'), findsOneWidget);
      expect(find.byKey(const ValueKey('coin-store-wallet')), findsOneWidget);
      expect(find.text('1,234'), findsWidgets);
      expect(find.text('Daily prize'), findsOneWidget);
      expect(find.text('Achievement rewards'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('billing-unavailable')),
      );
      expect(
        find.textContaining('Coin purchases are unavailable'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('restore-purchases')), findsNothing);
      expect(p.wallet, 1234);
      await tester.tap(find.byTooltip('Close coin store'));
      await settle(tester);
      expect(find.byType(CoinStoreSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unaffordable gear shows its exact shortfall and returns after rewards',
    (tester) async {
      final p = await openShop(tester, wallet: 50);
      final link = find.byKey(const ValueKey('get-coins-buy-coral'));
      await tester.scrollUntilVisible(
        link,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Need 10 more · Earn coins'), findsOneWidget);
      expect(find.byKey(const ValueKey('get-coins-buy-steel')), findsNothing);
      await tester.ensureVisible(link);
      await tester.pump();
      await tester.tap(
        find.descendant(of: link, matching: find.byType(TextButton)),
      );
      await settle(tester);
      expect(find.text('10 more coins for your item'), findsOneWidget);
      await tester.tap(find.text('Daily prize'));
      await settle(tester);
      final claim = find.text('CLAIM 10 COINS');
      await tester.ensureVisible(claim);
      await tester.tap(claim);
      await settle(tester);
      expect(p.wallet, 60);
      // A real daily reward, not a fabricated wallet top-up.
      expect(find.text('You received 10 coins!'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Close daily prizes'));
      await tester.tap(find.byTooltip('Close daily prizes'));
      await settle(tester);
      expect(find.text('You have enough for your item!'), findsOneWidget);
      await tester.tap(find.byTooltip('Close coin store'));
      await settle(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-coral')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
