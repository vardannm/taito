import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/shop_design.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/survival_upgrades.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;
import 'support/shop_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  testWidgets('shop expands from its button and returns without starting run', (
    tester,
  ) async {
    final game = await launch(tester, ControlMode.oneFinger);
    await tester.pump(const Duration(milliseconds: 700));
    final source = tester.getRect(find.byKey(const ValueKey('board-shop')));
    final serial = game.runSerial;
    await tester.tap(find.byKey(const ValueKey('board-shop')));
    await tester.pump();
    await tester.pump();
    final surface = find.byKey(const ValueKey('shop-reveal-surface'));
    final start = tester.getRect(surface);
    expect(start.left, closeTo(source.left, .01));
    expect(start.top, closeTo(source.top, .01));
    expect(start.size, source.size);
    await tester.pump(const Duration(milliseconds: 240));
    final middle = tester.getRect(surface);
    expect(middle.width, greaterThan(source.width));
    expect(middle.width, lessThan(320));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(surface), const Rect.fromLTWH(0, 0, 320, 568));
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Gear Shop'), findsOneWidget);
    expect(find.text('MAKE IT YOURS'), findsNothing);
    expect(game.runSerial, serial);
    expect(game.waitingForInput, isTrue);
    await tester.tap(find.byTooltip('Done shopping'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getSize(surface).width, lessThan(320));
    await tester.pump(const Duration(milliseconds: 300));
    expect(surface, findsNothing);
    expect(game.waitingForInput, isTrue);
    expect(game.score, 0);
    expect(game.controlHeld, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion opens immediately and system Back closes', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('Menu'));
          },
        ),
      ),
    );
    Navigator.of(pageContext).push(
      ShopRevealRoute(
        origin: const Rect.fromLTWH(20, 400, 48, 48),
        reducedMotion: true,
        builder: (_) => const Text('Collection'),
      ),
    );
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('shop-reveal-surface'))),
      const Rect.fromLTWH(0, 0, 800, 600),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Collection'), findsNothing);
    expect(find.text('Menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shop swipes gear independently, scrolls vertically, and keeps the run waiting',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byKey(const ValueKey('board-shop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      final balls = find.byKey(const ValueKey('ball-pages'));
      await tester.drag(balls, const Offset(-180, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('buy-coral')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('buy-platform-classic')),
        findsOneWidget,
      );
      // A rightward browse at the first ball must never close the shop.
      await tester.drag(balls, const Offset(180, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.drag(balls, const Offset(180, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BallShop), findsOneWidget);
      expect(find.byKey(const ValueKey('buy-steel')), findsOneWidget);
      final rail = find.byKey(const ValueKey('platform-pages'));
      await tester.ensureVisible(rail);
      await tester.drag(rail, const Offset(-180, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('buy-platform-copper')), findsOneWidget);
      expect(find.byKey(const ValueKey('buy-steel')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('upgrade-hearts')));
      expect(
        find.byKey(const ValueKey('upgrade-hearts')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Done shopping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('shop-swipe-area')), findsNothing);
      expect(find.byKey(const ValueKey('board-shop')), findsOneWidget);
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reopening the shop starts at the equipped loadout', (
    tester,
  ) async {
    final p = PlayerProfile(unlimitedCoins: true)..tutorialSeen = true;
    p.selectBall(BallCosmetic.quasar);
    p.selectPlatform(PlatformStyle.celestial);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: p)),
      ),
    );
    expect(find.byKey(const ValueKey('buy-quasar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('buy-platform-celestial')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('browsing leaves coins and equipped gear unchanged', (
    tester,
  ) async {
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..wallet = 1000;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: p)),
      ),
    );
    await revealShopBall(tester, BallCosmetic.neon);
    await revealShopPlatform(tester, PlatformStyle.ion);
    expect(p.wallet, 1000);
    expect(p.selectedBall, BallCosmetic.steel);
    expect(p.selectedPlatform, PlatformStyle.classic);
    expect(p.ownedBalls, isNot(contains(BallCosmetic.neon)));
    expect(p.ownedPlatforms, isNot(contains(PlatformStyle.ion)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('maxed upgrades disable purchases and hide coin shortfalls', (
    tester,
  ) async {
    final p = PlayerProfile()..tutorialSeen = true;
    for (final upgrade in SurvivalUpgrade.values) {
      p.survivalUpgrades[upgrade] = upgrade.maxLevel;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: p)),
      ),
    );
    for (final upgrade in SurvivalUpgrade.values) {
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(ValueKey('upgrade-${upgrade.name}')),
            )
            .onPressed,
        isNull,
      );
    }
    expect(find.byKey(const ValueKey('get-coins-upgrades')), findsNothing);
    expect(find.text('Max'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
