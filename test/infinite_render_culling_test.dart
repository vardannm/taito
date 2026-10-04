import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/spider_painter.dart';
import 'package:balance_arcade/snakes.dart';
import 'package:balance_arcade/snake_painter.dart';
import 'combo_render_budget_test.dart' show DrawingBudget;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offscreen spiders and snakes issue no drawing commands', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.spiders.add(BoardSpider(180, -2000, 100));
    game.snakes.add(BoardSnake(x: 180, y: -2000));
    final canvas = DrawingBudget();
    paintSpiderBackdrop(canvas, game);
    paintSpiders(canvas, game, false);
    paintSnakes(canvas, game, false);
    expect(canvas.draws, 0);
    game.cameraOffset = 2300;
    paintSpiderBackdrop(canvas, game);
    paintSpiders(canvas, game, false);
    paintSnakes(canvas, game, false);
    expect(canvas.draws, greaterThan(0));
  });

  test('an offscreen snake head does not hide its visible tail', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    final snake = BoardSnake(x: 180, y: 650);
    snake.points = List.generate(
      BoardSnake.samples,
      (i) => (x: 180.0, y: 650.0 - i * 6),
    );
    game.snakes.add(snake);
    final canvas = DrawingBudget();
    paintSnakes(canvas, game, false);
    expect(canvas.draws, greaterThan(0));
  });

  test('generated holes outside the viewport add no board draw work', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    final baseline = DrawingBudget();
    BoardPainter(game, showHud: false).paint(baseline, const Size(360, 560));
    game.board.addAll(List.generate(100, (i) => Hole(180, -2000 - i * 50.0)));
    final extra = DrawingBudget();
    BoardPainter(game, showHud: false).paint(extra, const Size(360, 560));
    expect(extra.draws, baseline.draws);
  });

  test('cached snake geometry preserves radii and body formula', () {
    final snake = BoardSnake(x: 200, y: 300, phase: .7);
    snake.step(.25);
    final speed = math.sqrt(snake.vx * snake.vx + snake.vy * snake.vy);
    final dx = snake.vx / speed, dy = snake.vy / speed;
    for (var i = 0; i < BoardSnake.samples; i++) {
      final u = i / (BoardSnake.samples - 1);
      final distance = BoardSnake.length * u;
      final wave =
          math.sin(snake.age * 5.5 - distance * .073 + snake.phase) *
          (3 + 9 * math.sin(u * math.pi));
      expect(snake.radiusAt(i), 1.2 + 7.3 * math.pow(1 - u, .6));
      expect(snake.points[i].x, snake.x - dx * distance - dy * wave);
      expect(snake.points[i].y, snake.y - dy * distance + dx * wave);
    }
  });
}
