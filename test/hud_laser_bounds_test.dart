import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/hazard_painter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact;

class BeamCanvas implements Canvas {
  final lines = <(Offset, Offset)>[];
  final rectangles = <Rect>[];
  @override
  void drawLine(Offset a, Offset b, Paint paint) => lines.add((a, b));
  @override
  void drawRect(Rect rect, Paint paint) => rectangles.add(rect);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('laser warnings, live beams and contact share the expanded top', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    final laser = SpecialHazard(HazardKind.laser, x: 180, y: 90);
    game.specialHazards.add(laser);
    for (final top in [0.0, -100.0, -220.0]) {
      game.visibleTop = top;
      final canvas = BeamCanvas();
      paintSpecialHazards(canvas, game, true);
      expect(canvas.rectangles.single.top, top + 33);
      laser.step(.01, 0);
      expect(
        laser.contact(180, top + 50, 180, top + 50, boardTop: top),
        isNull,
      );
    }
    laser.step(2.1, 0);
    laser.step(.01, 0);
    final canvas = BeamCanvas();
    paintSpecialHazards(canvas, game, true);
    expect(
      canvas.lines,
      contains((const Offset(180, -187), const Offset(180, 537))),
    );
    expect(laser.contact(150, -100, 210, -100, boardTop: -220), isNotNull);
    expect(laser.contact(150, -200, 210, -200, boardTop: -220), isNull);
    expect(laser.contact(150, -100, 210, -100), isNull);
    // Rotation/resize back to the original height does not retain a stale top.
    game.visibleTop = 0;
    final compact = BeamCanvas();
    paintSpecialHazards(compact, game, true);
    expect(
      compact.lines,
      contains((const Offset(180, 33), const Offset(180, 537))),
    );
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('heart icons track remaining lives on $size', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final game = await launch(tester, ControlMode.twoFinger, size: size);
      await tester.tapAt(contact(tester, game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      game.survival.recovery = 100;
      for (final lives in [3, 2, 1]) {
        game.lives = lives;
        await tester.pump(const Duration(milliseconds: 30));
        final hearts = find.byKey(const ValueKey('board-hearts'));
        expect(
          tester.widget<Semantics>(hearts).properties.label,
          '$lives of 3 hearts remaining',
        );
        expect(
          find.descendant(
            of: hearts,
            matching: find.byIcon(Icons.favorite_rounded),
          ),
          findsNWidgets(lives),
        );
        expect(
          find.descendant(
            of: hearts,
            matching: find.byIcon(Icons.favorite_border_rounded),
          ),
          findsNWidgets(3 - lives),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
