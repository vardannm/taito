import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/coin_store.dart';
import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/shop_product_card.dart';
import 'package:balance_arcade/shop_product_sheet.dart';
import 'package:balance_arcade/survival_upgrades.dart';

import 'support/controlled_shop_storage.dart';
import 'support/shop_actions.dart';

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  late ControlledShopStorage storage;
  setUp(() {
    storage = ControlledShopStorage();
    SharedPreferencesAsyncPlatform.instance = storage;
  });

  Future<void> launch(
    WidgetTester tester,
    PlayerProfile profile, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    profile.tutorialSeen = true;
    profile.haptics = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(body: BallShop(profile: profile)),
      ),
    );
    await tester.pump();
  }

  Future<void> openCoral(WidgetTester tester) async {
    final buy = find.byKey(const ValueKey('buy-coral')).hitTestable();
    await tester.scrollUntilVisible(
      buy,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(buy);
    await frames(tester);
  }

  testWidgets('preview and cancel disclose benefits and never spend coins', (
    tester,
  ) async {
    final p = PlayerProfile()..wallet = 60;
    await launch(tester, p);
    await openCoral(tester);
    expect(find.byType(ShopProductSheet), findsOneWidget);
    expect(find.text('Coral Lagoon included'), findsOneWidget);
    expect(find.text('After purchase  0'), findsOneWidget);
    expect(p.wallet, 60);
    expect(p.ownedBalls.contains(BallCosmetic.coral), isFalse);
    await tester.tap(find.byTooltip('Close item details'));
    await frames(tester);
    expect(find.byType(ShopProductSheet), findsNothing);
    expect(p.wallet, 60);
  });

  testWidgets(
    'saving blocks double taps and success appears only after a durable grant',
    (tester) async {
      final p = PlayerProfile()..wallet = 60;
      await launch(tester, p);
      await openCoral(tester);
      storage.gate = Completer<void>();
      final confirm = find.byKey(const ValueKey('confirm-shop-purchase'));
      await tester.tap(confirm);
      await tester.pump();
      expect(find.text('Saving purchase…'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(p.wallet, 60);
      expect(p.selectedBall, BallCosmetic.steel);
      storage.gate!.complete();
      await frames(tester);
      expect(
        find.byKey(const ValueKey('shop-purchase-success')).hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('Added to your collection'), findsOneWidget);
      expect(p.wallet, 0);
      expect(p.selectedBall, BallCosmetic.coral);
      await tester.tap(confirm);
      await frames(tester);
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.selectedBall, BallCosmetic.coral);
      expect(restored.wallet, 0);
    },
  );

  testWidgets('save errors are visible, retain the quote and support retry', (
    tester,
  ) async {
    final p = PlayerProfile()..wallet = 60;
    await launch(tester, p, size: const Size(320, 568), scale: 1.8);
    await openCoral(tester);
    storage.fail = true;
    final confirm = find.byKey(const ValueKey('confirm-shop-purchase'));
    await tester.tap(confirm);
    await frames(tester);
    expect(find.text('Purchase not completed').hitTestable(), findsOneWidget);
    expect(find.textContaining('No coins were spent'), findsOneWidget);
    expect(p.wallet, 60);
    expect(p.selectedBall, BallCosmetic.steel);
    storage.fail = false;
    await tester.tap(confirm);
    await frames(tester);
    expect(
      find.byKey(const ValueKey('shop-purchase-success')).hitTestable(),
      findsOneWidget,
    );
    expect(p.wallet, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance changes at confirmation show the real shortfall', (
    tester,
  ) async {
    final p = PlayerProfile()..wallet = 60;
    await launch(tester, p);
    await openCoral(tester);
    p.wallet = 50;
    await tester.tap(find.byKey(const ValueKey('confirm-shop-purchase')));
    await frames(tester);
    expect(find.text('Need 10 more coins'), findsOneWidget);
    expect(p.ownedBalls.contains(BallCosmetic.coral), isFalse);
    await tester.tap(find.byKey(const ValueKey('confirm-shop-purchase')));
    await frames(tester);
    expect(find.byType(CoinStoreSheet), findsOneWidget);
    expect(find.text('10 more coins for your item'), findsOneWidget);
  });

  testWidgets(
    'search finds world names, filters have recovery and owned gear equips for free',
    (tester) async {
      final p = PlayerProfile()
        ..wallet = 0
        ..ownedBalls.add(BallCosmetic.aurora);
      await launch(tester, p);
      final search = find.byKey(const ValueKey('shop-search-0'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'polar');
      await tester.pump();
      expect(find.byType(ShopProductCard), findsOneWidget);
      expect(find.text('Aurora'), findsOneWidget);
      final equip = find.byKey(const ValueKey('buy-aurora')).hitTestable();
      await tester.scrollUntilVisible(
        equip,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(equip);
      await completeShopPurchase(tester);
      expect(p.selectedBall, BallCosmetic.aurora);
      expect(p.wallet, 0);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'no such world');
      await tester.pump();
      final reset = find.text('Show all items');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump();
      expect(find.text('No items here yet'), findsNothing);
      await tester.ensureVisible(find.text('Can afford'));
      await tester.tap(find.text('Can afford'));
      await tester.pump();
      expect(find.text('No items here yet'), findsOneWidget);
    },
  );

  testWidgets('tabs preserve catalog scroll position, query and sort', (
    tester,
  ) async {
    final p = PlayerProfile()..wallet = 100000;
    await launch(tester, p);
    final list = find
        .descendant(
          of: find.byKey(const ValueKey('collection-0')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -700));
    await tester.pump();
    final offset = tester.state<ScrollableState>(list).position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Platforms'));
    await tester.pump();
    await tester.tap(find.text('Balls'));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(list).position.pixels,
      closeTo(offset, .1),
    );
    await tester.drag(list, const Offset(0, 1500));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Sort collection'));
    await tester.tap(find.byTooltip('Sort collection'));
    await frames(tester);
    await tester.tap(find.text('Price: high to low'));
    await frames(tester);
    expect(find.text('23 worlds · Price: high to low'), findsOneWidget);
    expect(
      tester
          .widgetList<ShopProductCard>(find.byType(ShopProductCard))
          .first
          .product
          .ball,
      BallCosmetic.genesis,
    );
  });

  for (final (size, scale) in [
    (const Size(320, 568), 2.0),
    (const Size(540, 720), 1.0),
    (const Size(820, 1180), 1.0),
    (const Size(1440, 900), 1.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'catalog, maximum upgrades and details fit $size at scale $scale',
      (tester) async {
        final p = PlayerProfile()
          ..wallet = 0
          ..survivalUpgrades[SurvivalUpgrade.magnet] = 5;
        await launch(tester, p, size: size, scale: scale);
        final tabs = find.byType(MenuTabs);
        expect(tester.getRect(tabs).height, lessThan(100));
        await tester.tap(find.text('Upgrades'));
        await tester.pump();
        final maxed = find.byKey(const ValueKey('upgrade-magnet'));
        await tester.scrollUntilVisible(
          maxed.hitTestable(),
          130,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<FilledButton>(maxed).onPressed, isNull);
        expect(find.text('Fully upgraded'), findsOneWidget);
        final preview = find
            .byKey(const ValueKey('preview-upgrade-magnet'))
            .hitTestable();
        await tester.scrollUntilVisible(
          preview,
          -130,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(preview);
        await frames(tester);
        expect(find.byType(ShopProductSheet), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('confirm-shop-purchase')),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
