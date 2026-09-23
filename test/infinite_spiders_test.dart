import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/infinite_progress.dart';

void main() {
  test(
    'spider territories enter from above, stay separated and are pruned',
    () {
      for (var seed = 0; seed < 20; seed++) {
        final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
        expect(g.spiders, isEmpty);
        final seen = <BoardSpider>{};
        for (var offset = 100.0; offset < 45000; offset += 100) {
          g.cameraOffset = offset;
          g.maxHeight = offset;
          g.ensureInfiniteBoard();
          expect(g.spiders.length, lessThanOrEqualTo(3));
          for (final s in g.spiders) {
            if (seen.add(s)) {
              expect(g.screenY(s.zoneY) + s.zoneRadius, lessThan(0));
            }
            for (final h in g.board) {
              expect(
                math.sqrt(
                  math.pow(s.zoneX - h.x, 2) + math.pow(s.zoneY - h.y, 2),
                ),
                greaterThanOrEqualTo(s.zoneRadius + 20),
              );
            }
          }
        }
        expect(seen.length, greaterThan(5));
        g.start(gameMode: GameMode.infinite);
        expect(g.spiders, isEmpty);
      }
    },
  );

  test('spider hits use hearts, recovery, shields and final-life rules', () {
    final g = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
    g.board.clear();
    final s = BoardSpider(g.ballX - 12, g.ballY, 38);
    g.spiders.add(s);
    g.step(1 / 120);
    expect(s.chasing, isTrue);
    expect(g.lives, 2);
    expect(g.phase, GamePhase.playing);
    expect(g.survival.recovery, greaterThan(0));
    g.step(1 / 120);
    expect(g.lives, 2);
    g.survival.recovery = 0;
    g.survival.items.add(
      InfiniteItem(InfiniteItemKind.shield, g.ballX, g.ballY),
    );
    g.step(1 / 120);
    expect(g.lives, 2);
    g.survival.shield = 0;
    g.lives = 1;
    g.step(1 / 120);
    expect(g.phase, GamePhase.sinking);
    expect(g.lives, 0);
    expect(g.message, contains('spider'));
  });
}
