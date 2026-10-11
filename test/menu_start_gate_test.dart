import 'package:balance_arcade/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch, contact;
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final control in ControlMode.values) {
    testWidgets(
      '$control swipes from top and hero, then waits for Play and input',
      (tester) async {
        final game = await launch(tester, control);
        await tester.tapAt(contact(tester, game));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
        await tester.pump(const Duration(seconds: 2));
        expect(game.waitingForInput, isTrue);
        expect(game.elapsed, 0);
        expect(game.controlHeld, isFalse);
        for (final y in [40.0, 160.0, 260.0]) {
          await tester.dragFrom(Offset(240, y), const Offset(-210, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(game.mode, GameMode.classic, reason: 'Swipe at y=$y');
          await selectWorld(tester, 0);
        }
        final serial = game.runSerial;
        await armWorld(tester);
        expect(
          find.byKey(const ValueKey('start-control-prompt')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(game.waitingForInput, isTrue);
        expect(game.elapsed, 0);
        expect(game.score, 0);
        expect(game.runSerial, serial);
        final finger = await tester.startGesture(contact(tester, game));
        await finger.moveBy(const Offset(3, -3));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.waitingForInput, isFalse);
        expect(game.elapsed, greaterThan(0));
        expect(game.runSerial, serial);
        expect(
          find.byKey(const ValueKey('start-control-prompt')),
          findsNothing,
        );
        await finger.up();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'pause has large filled actions and Back to Menu resets the gate',
    (tester) async {
      final game = await launch(tester, ControlMode.analog);
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      for (final label in ['RESUME RUN', 'RESTART RUN', 'BACK TO MENU']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        );
        expect(button, findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(58));
      }
      await tester.tap(find.text('BACK TO MENU'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byKey(const ValueKey('menu-play')), findsOneWidget);
      await tester.tapAt(contact(tester, game));
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
