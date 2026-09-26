import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/spider_painter.dart';
import 'package:balance_arcade/infinite_painter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact;

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

class WebCanvas implements Canvas {
  final colors = <Color>[];
  @override
  void drawLine(Offset a, Offset b, Paint paint) => colors.add(paint.color);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test(
    'foreground maintains contrast across all tiers and intermediate fades',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      for (final cabinet in CabinetStyle.values) {
        game.cabinet = cabinet;
        for (var step = 0; step <= 100; step++) {
          game.survival.visualCombo = step / 100;
          for (final p in [
            const Offset(110, 60),
            const Offset(180, 270),
            const Offset(315, 510),
          ]) {
            expect(
              contrast(infiniteBoardInk(game, p), infiniteFieldColor(game, p)),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
    },
  );

  test('web strands switch from dark to light with the actual field', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.spiders
      ..clear()
      ..add(BoardSpider(180, 280, 45));
    for (final power in [0.0, 1.0]) {
      game.survival.visualCombo = power;
      final canvas = WebCanvas();
      paintSpiderBackdrop(canvas, game);
      expect(canvas.colors, isNotEmpty);
      expect(
        canvas.colors.first.toARGB32(),
        (power == 0 ? Colors.black : Colors.white).withAlpha(180).toARGB32(),
      );
    }
  });

  testWidgets('HUD updates contrast during combo gains and losses', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final game = await launch(tester, ControlMode.twoFinger);
    await tester.tapAt(contact(tester, game));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    game.survival.recovery = 100;
    for (final combo in [1, 5, 6, 10, 1]) {
      game.survival.combo = combo;
      game.survival.visualCombo = (combo - 1) / 9;
      await tester.pump(const Duration(milliseconds: 32));
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('board-hud')),
          matching: find.byType(Text),
        ),
      );
      expect(
        texts.first.style!.color,
        infiniteBoardInk(game, const Offset(110, 60)),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
