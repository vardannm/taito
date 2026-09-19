import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/mode_carousel.dart';
import 'package:balance_arcade/control_hint.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact, expectOwned;
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final control in ControlMode.values) {
    testWidgets(
      '$control hint moves over its control and cannot consume the starting touch',
      (tester) async {
        final game = await launch(tester, control);
        expect(find.byType(ControlHint), findsOneWidget);
        final fingerIcon = find.byKey(const ValueKey('hint-finger-0'));
        final initial = tester.getTopLeft(fingerIcon);
        await tester.pump(const Duration(milliseconds: 550));
        expect(tester.getTopLeft(fingerIcon).dy, lessThan(initial.dy - 10));
        expect(game.elapsed, 0);
        final finger = await tester.startGesture(contact(tester, game));
        await finger.moveBy(const Offset(0, -4));
        expect(game.waitingForInput, isFalse);
        expectOwned(game);
        await tester.pump();
        expect(find.byType(ControlHint), findsNothing);
        await tester.pump(const Duration(milliseconds: 600));
        expectOwned(game);
        await finger.up();
        final dynamic state = tester.state(find.byType(GameScreen));
        state.home();
        await tester.pump();
        expect(find.byType(ControlHint), findsNothing);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(find.byType(ControlHint), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      testWidgets(
        '$control painted gameplay actually fills the width at $size',
        (tester) async {
          final game = await launch(tester, control, size: size);
          for (var mode = 0; mode < arcadeModes.length; mode++) {
            await selectWorld(tester, mode);
            await startWorld(tester);
            await tester.pump(const Duration(milliseconds: 600));
            final paintFinder = find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is BoardPainter,
            );
            final painter =
                tester.widget<CustomPaint>(paintFinder).painter!
                    as BoardPainter;
            final bounds = tester.getSize(paintFinder);
            final viewport = BoardViewport.forGame(
              bounds,
              game,
              fillWidth: painter.fillWidth,
            );
            // Assert painted edges, not just the outer PageView's logical width.
            expect(painter.fillWidth, 1);
            expect(viewport.rect.left, closeTo(0, .001));
            expect(viewport.rect.right, closeTo(size.width, .001));
            final platform = viewport.project(
              Offset(180, game.screenY((game.left + game.right) / 2)),
            );
            expect(platform.dy, inInclusiveRange(0, bounds.height));
            final dynamic state = tester.state(find.byType(GameScreen));
            state.home();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('reduced motion keeps the finger hint stationary', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester, ControlMode.oneFinger);
    final icon = find.byKey(const ValueKey('hint-finger-0'));
    final before = tester.getTopLeft(icon);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getTopLeft(icon), before);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });

  test('full-width camera reveals the entire route as the platform rises', () {
    for (final y in [30.0, 100.0, 280.0, 440.0, 526.0]) {
      final viewport = BoardViewport(
        const Size(320, 220),
        fillWidth: 1,
        focusY: y,
      );
      expect(viewport.rect.width, closeTo(320, .001));
      expect(viewport.project(Offset(180, y)).dy, inInclusiveRange(0, 220));
      expect(viewport.scale, closeTo(320 / 360, .001));
    }
  });
}
