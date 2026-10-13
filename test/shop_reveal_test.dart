import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/shop_design.dart';
import 'package:balance_arcade/menu_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;

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
    'shop swipes tabs, keeps vertical scrolling, and exits left from Balls',
    (tester) async {
      final game = await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byKey(const ValueKey('board-shop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      int selected() => tester.widget<MenuTabs>(find.byType(MenuTabs)).selected;
      Future<void> swipe(double dx) async {
        await tester.dragFrom(const Offset(160, 280), Offset(dx, 0));
        await tester.pump();
      }

      expect(selected(), 0);
      await tester.dragFrom(const Offset(160, 380), const Offset(0, -140));
      await tester.pump();
      expect(selected(), 0);
      final ballList = find.byKey(const ValueKey('collection-0'));
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: ballList, matching: find.byType(Scrollable)),
            )
            .position
            .pixels,
        greaterThan(0),
      );
      for (var tab = 1; tab <= 3; tab++) {
        await swipe(110);
        expect(selected(), tab);
      }
      await swipe(110);
      expect(selected(), 3);
      for (var tab = 2; tab >= 0; tab--) {
        await swipe(-110);
        expect(selected(), tab);
      }
      final smallDrag = await tester.startGesture(const Offset(160, 280));
      await smallDrag.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 300));
      await smallDrag.up();
      await tester.pump();
      expect(selected(), 0);
      await swipe(-110);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('shop-swipe-area')), findsNothing);
      expect(find.byKey(const ValueKey('menu-play')), findsOneWidget);
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
