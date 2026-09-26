import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/rewards.dart';

BalanceGame cleanRun({BallCosmetic ball = BallCosmetic.steel}) {
  final g = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
  g.cosmetic = ball;
  g.mazeSectionsEnabled = false;
  g.board.clear();
  g.coins.clear();
  g.spiders.clear();
  g.survival.items.clear();
  g.survival.nextComboY = g.survival.nextShieldY = g.survival.nextHeartY =
      g.survival.nextMagnetY = -1e9;
  return g;
}

void tick(BalanceGame g) => g.step(1 / 120);
void pullFor(BalanceGame g, int ticks) {
  for (var i = 0; i < ticks; i++) {
    tick(g);
  }
}

void main() {
  test('pulling pauses in place and only contact activates a shield', () {
    final g = cleanRun()..survival.magnet = 10;
    final shield = InfiniteItem(
      InfiniteItemKind.shield,
      g.ballX + 150,
      g.ballY,
    );
    g.survival.items.add(shield);
    tick(g);
    final at = (shield.x, shield.y);
    expect(shield.x, lessThan(g.ballX + 150));
    expect(g.survival.shield, 0);
    g.setPaused(true);
    pullFor(g, 120);
    expect((shield.x, shield.y), at);
    g.setPaused(false);
    pullFor(g, 70);
    expect(g.survival.items, isEmpty);
    expect(g.survival.shield, greaterThan(0));
  });

  test(
    'magnet visibly pulls every reward kind before collecting, leaving distant rewards',
    () {
      final g = cleanRun()..lives = 2;
      final far = BrassCoin(g.ballX, g.ballY - 300);
      g.coins.addAll([BrassCoin(g.ballX + 90, g.ballY), far]);
      g.survival.items.addAll([
        InfiniteItem(InfiniteItemKind.magnet, g.ballX, g.ballY),
        InfiniteItem(InfiniteItemKind.combo, g.ballX + 70, g.ballY),
        InfiniteItem(InfiniteItemKind.shield, g.ballX - 80, g.ballY),
        InfiniteItem(InfiniteItemKind.heart, g.ballX, g.ballY - 100),
      ]);
      tick(g);
      expect(g.survival.magnet, InfiniteTuning.magnetSeconds);
      expect(g.survival.combo, 1);
      expect(g.survival.shield, 0);
      expect(g.lives, 2);
      expect(g.coinsCollected, 0);
      final beforeX = g.coins.first.x;
      tick(g);
      expect(g.coins.first.x, lessThan(beforeX));
      expect(g.coins.first.collected, false);
      pullFor(g, 70);
      expect(g.survival.combo, 2);
      expect(g.survival.shield, greaterThan(9));
      expect(g.lives, 3);
      expect(g.coinsCollected, 1);
      expect(far.collected, false);
      expect(g.survival.items, isEmpty);
      tick(g);
      expect(g.coinsCollected, 1);
      expect(g.survival.combo, 2);
    },
  );

  test(
    'timer pauses, refreshes, expires to passive range and resets on retry',
    () {
      final g = cleanRun(ball: BallCosmetic.plasma);
      g.survival.magnet = 3;
      g.setPaused(true);
      g.step(1);
      expect(g.survival.magnet, 3);
      g.setPaused(false);
      g.survival.items.add(
        InfiniteItem(InfiniteItemKind.magnet, g.ballX + 100, g.ballY),
      );
      tick(g);
      expect(g.survival.magnet, lessThan(3));
      for (var i = 0; i < 120 && g.survival.magnet < 4; i++) {
        tick(g);
      }
      expect(g.survival.magnet, 12);
      g.survival.magnet = .001;
      tick(g);
      expect(g.survival.magnet, 0);
      expect(g.magnetRadius, BallCosmetic.plasma.magnetRadius);
      g.survival.magnet = 8;
      g.start(gameMode: GameMode.infinite);
      expect(g.survival.magnet, 0);
      expect(g.magnetRadius, BallCosmetic.plasma.magnetRadius);
    },
  );

  test(
    'equipped ball tiers have different reach and nonmagnetic balls need contact',
    () {
      for (final ball in BallCosmetic.values) {
        final g = cleanRun(ball: ball);
        final near = BrassCoin(g.ballX + 30, g.ballY);
        final medium = BrassCoin(g.ballX + 75, g.ballY);
        final far = BrassCoin(g.ballX + 120, g.ballY);
        g.coins.addAll([near, medium, far]);
        tick(g);
        expect(near.collected, false);
        expect(medium.collected, false);
        pullFor(g, 60);
        expect(near.collected, ball.magnetRadius >= 30, reason: ball.name);
        expect(medium.collected, ball.magnetRadius >= 75, reason: ball.name);
        expect(far.collected, false, reason: ball.name);
        g.start(gameMode: GameMode.classic);
        expect(g.magnetRadius, 0);
        g.start(gameMode: GameMode.laserMaze);
        expect(g.magnetRadius, 0);
      }
    },
  );

  for (final magnetFirst in [true, false]) {
    test('mid-swipe magnet respects earlier hazard order ($magnetFirst)', () {
      final g = cleanRun();
      g.board.add(const Hole(180, 350));
      g.survival.items.addAll([
        InfiniteItem(InfiniteItemKind.magnet, 180, magnetFirst ? 400 : 300),
        InfiniteItem(InfiniteItemKind.shield, 270, 330),
      ]);
      g.grabPivot(0);
      g.grabPivot(1);
      g.dragPivot(0, -200);
      g.dragPivot(1, -200);
      tick(g);
      expect(g.lives, 2);
      expect(g.survival.shield, 0); // It must physically arrive first.
      pullFor(g, 70);
      expect(g.survival.shield, greaterThan(0));
    });
  }

  test('fatal collision does not collect later magnet or coins', () {
    final g = cleanRun()..lives = 1;
    g.board.add(const Hole(180, 390));
    g.survival.items.add(InfiniteItem(InfiniteItemKind.magnet, 180, 300));
    g.coins.add(BrassCoin(180, 290));
    g.grabPivot(0);
    g.grabPivot(1);
    g.dragPivot(0, -200);
    g.dragPivot(1, -200);
    tick(g);
    expect(g.phase, isNot(GamePhase.playing));
    expect(g.lives, 0);
    expect(g.survival.magnet, 0);
    expect(g.coinsCollected, 0);
  });

  test('passive field does not attract traps or grant protection', () {
    final g = cleanRun(ball: BallCosmetic.singularity);
    final hole = Hole(g.ballX + 50, g.ballY);
    g.board.add(hole);
    tick(g);
    expect(g.lives, 3);
    expect(g.board, contains(hole));
    g.board.add(Hole(g.ballX, g.ballY));
    tick(g);
    expect(g.lives, 2);
  });

  test('magnets spawn naturally with bounded pickup storage', () {
    final g = cleanRun();
    g.survival.nextMagnetY = InfiniteTuning.firstMagnetY;
    final seen = <InfiniteItem>{};
    for (var i = 0; i < 140; i++) {
      g.cameraOffset = i * 60.0;
      g.left = g.right = 440 - g.cameraOffset;
      g.survival.shield = 100;
      g.stallTime = 0;
      tick(g);
      seen.addAll(
        g.survival.items.where((i) => i.kind == InfiniteItemKind.magnet),
      );
      expect(
        g.survival.items.length,
        lessThanOrEqualTo(InfiniteTuning.maxItems),
      );
    }
    expect(seen.length, greaterThan(1));
  });
}
