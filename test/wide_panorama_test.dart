import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/wide_board_scenery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'combo_render_budget_test.dart' show DrawingBudget;

class RailCanvas extends DrawingBudget {
  final rails = <double>[];
  final lasers = <double>[];

  @override
  void drawLine(Offset a, Offset b, Paint paint) {
    if (a.dx != b.dx) return;
    if (paint.strokeWidth == 5 && paint.color.toARGB32() == 0xFF574A31) {
      rails.add(a.dx);
      expect(paint.maskFilter, isNull);
    }
    if (paint.strokeWidth == BalanceGame.sideLaserWidth &&
        paint.color.toARGB32() == 0xFFE34336) {
      lasers.add(a.dx);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in GameMode.values) {
    test(
      '$mode paints border rails and two scenery blur passes without changing play',
      () {
        final game = BalanceGame(seed: 41)..start(gameMode: mode);
        final before = (
          game.ballX,
          game.ballY,
          game.left,
          game.right,
          game.cameraOffset,
          game.clock,
          game.runSerial,
          game.score,
        );
        for (final size in [const Size(1114, 720), const Size(1920, 1080)]) {
          final view = BoardViewport.forGame(size, game, fillWidth: 1);
          final canvas = RailCanvas();
          BoardPainter(game, fillWidth: 1, showHud: false).paint(canvas, size);
          expect(canvas.rails, [view.railLeft, view.railRight]);
          expect(
            view.project(Offset(canvas.rails.first, 0)).dx,
            closeTo(24, .001),
          );
          expect(
            view.project(Offset(canvas.rails.last, 0)).dx,
            closeTo(size.width - 24, .001),
          );
          expect(canvas.layers, 2);
          expect((
            game.ballX,
            game.ballY,
            game.left,
            game.right,
            game.cameraOffset,
            game.clock,
            game.runSerial,
            game.score,
          ), before);
        }
      },
    );
  }

  test(
    'phone and carousel rails retain their original artwork without blur layers',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.practice);
      for (final (size, fill) in [
        (const Size(390, 844), 1.0),
        (const Size(540, 720), 1.0),
        (const Size(1114, 720), 0.0),
      ]) {
        final canvas = RailCanvas();
        BoardPainter(game, fillWidth: fill, showHud: false).paint(canvas, size);
        expect(canvas.rails, [20, 340]);
        expect(canvas.layers, 0);
      }
    },
  );

  test('laser hazards remain aligned with their actual collision rails', () {
    final game = BalanceGame()
      ..start(gameMode: GameMode.classic, levelNumber: 31);
    final canvas = RailCanvas();
    BoardPainter(
      game,
      fillWidth: 1,
      showHud: false,
    ).paint(canvas, const Size(1114, 720));
    expect(canvas.rails.length, 2);
    expect(canvas.lasers, containsAll([20.0, 340.0]));
    expect(game.laserSideRails, isTrue);
    expect(BalanceGame.sideLaserContactX, 30);
  });

  test(
    'scenery blur is sharp centrally and increases smoothly toward both edges',
    () {
      const size = Size(1920, 1080), sharp = Rect.fromLTRB(680, 96, 1240, 1080);
      for (final x in [680.0, 800.0, 960.0, 1200.0, 1240.0]) {
        expect(wideSceneryBlurAmount(x, sharp, size), 0);
      }
      expect(wideSceneryBlurAmount(0, sharp, size), 1);
      expect(wideSceneryBlurAmount(1920, sharp, size), 1);
      var previous = 0.0;
      for (var step = 0; step <= 100; step++) {
        final x = 680 * (1 - step / 100);
        final amount = wideSceneryBlurAmount(x, sharp, size);
        expect(amount, greaterThanOrEqualTo(previous));
        expect(
          amount,
          closeTo(wideSceneryBlurAmount(1920 - x, sharp, size), .00001),
        );
        previous = amount;
      }
    },
  );
}
