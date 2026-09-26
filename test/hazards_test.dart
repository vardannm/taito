import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';

void main() {
  test('sweeping laser warns still and detects its own sweep over a ball', () {
    final h = SpecialHazard(
      HazardKind.laser,
      x: 180,
      y: 55,
      sweeping: true,
      liveSeconds: 3.5,
    );
    h.step(2, 100);
    expect(h.x, 180);
    expect(h.hits(210, 300, 210, 300), isFalse);
    h.step(.5, 100);
    expect(h.x, greaterThan(220));
    expect(h.hits(210, 300, 210, 300), isTrue);
    expect(h.hits(300, 300, 300, 300), isFalse);
  });
  test(
    'zigzag enters from above, reverses horizontally and stays in bounds',
    () {
      final h = SpecialHazard(
        HazardKind.movingHole,
        x: 180,
        y: 55,
        zigzag: true,
        liveSeconds: 4,
      );
      h.step(2, 100);
      expect(h.y, 55);
      h.step(.5, 100);
      final right = h.x;
      expect(right, greaterThan(180));
      expect(h.y, closeTo(140, .001));
      for (var i = 0; i < 120; i++) {
        h.step(1 / 120, 100);
        expect(h.x, inInclusiveRange(55, 305));
      }
      expect(h.x, lessThan(right));
      expect(h.y, greaterThan(140));
    },
  );
  test(
    'hard variants cycle through sweep, zigzag and orbit only in late encounters',
    () {
      for (final height in [9000.0, 24000.0, 43200.0, 42900.0]) {
        final g = BalanceGame(seed: 42)
          ..start(gameMode: GameMode.infinite)
          // Maze and snake encounters have their own tests; this one is about the
          // ordinary hazard scheduler.
          ..mazeSectionsEnabled = false
          ..snakeEncountersEnabled = false;
        final variants = <int>[];
        for (var i = 0; i < 10; i++) {
          g.maxHeight = height;
          g.elapsed += 20;
          g.specialHazards.clear();
          g.board.clear();
          g.stallTime = 0;
          g.step(1 / 120);
          for (final h in g.specialHazards) {
            if (h.sweeping || h.zigzag || h.motion == HazardMotion.circle) {
              variants.add(
                h.sweeping
                    ? 0
                    : h.zigzag
                    ? 1
                    : 2,
              );
            }
          }
        }
        if (height == 42900) {
          expect(variants.length, greaterThan(2));
          expect(variants, contains(2));
          for (var i = 1; i < variants.length; i++) {
            expect(variants[i], (variants[i - 1] + 1) % 3);
          }
        } else {
          expect(variants, isEmpty);
        }
      }
    },
  );
  for (final kind in HazardKind.values) {
    test(
      '$kind is harmless throughout warning and lethal after activation',
      () {
        final h = SpecialHazard(kind, x: 180, y: 300);
        h.step(1.99, 0);
        expect(h.warning, isTrue);
        expect(h.hits(180, 300, 180, 300), isFalse);
        h.step(.02, 0);
        expect(h.active, isTrue);
        expect(h.hits(180, 300, 180, 300), isTrue);
        h.step(4, 0);
        h.step(.01, 0);
        expect(h.expired, isTrue);
        expect(h.hits(180, 300, 180, 300), isFalse);
      },
    );
  }
  test('warning holes hold position, then open and travel with the board', () {
    final h = SpecialHazard(HazardKind.formingHole, x: 100, y: 120);
    h.step(1.5, 180);
    expect(h.y, 120);
    h.step(.6, 180);
    expect(h.y, closeTo(138, .001));
    expect(h.hits(100, 130, 100, 130), isTrue);
  });
  test('moving-hole relative collision catches a crossing between frames', () {
    final h = SpecialHazard(
      HazardKind.movingHole,
      x: 180,
      y: 300,
      warningSeconds: 0,
    );
    h.step(.5, 0);
    expect(h.x, greaterThan(210));
    expect(h.hits(200, 300, 200, 300), isTrue);
    expect(h.hits(300, 300, 300, 300), isFalse);
  });
  test(
    'laser catches a fast crossing but never penalizes the warning fraction',
    () {
      final h = SpecialHazard(HazardKind.laser, x: 180, y: 0);
      h.step(1.99, 0);
      h.step(.02, 0);
      expect(h.hits(170, 300, 230, 300), isFalse);
      h.step(.01, 0);
      expect(h.hits(100, 300, 250, 300), isTrue);
      expect(h.hits(100, 10, 250, 10), isFalse);
    },
  );
  test(
    'platform gap removes only its section and repairs after its lifetime',
    () {
      final h = SpecialHazard(
        HazardKind.platformGap,
        x: 180,
        y: 0,
        liveSeconds: 2.5,
      );
      h.step(2.1, 0);
      h.step(.01, 0);
      expect(h.hits(80, 300, 100, 300), isFalse);
      expect(h.hits(120, 300, 240, 300), isTrue);
      h.step(2.5, 0);
      h.step(.01, 0);
      expect(h.active, isFalse);
      expect(h.hits(180, 300, 180, 300), isFalse);
    },
  );
  test(
    'all four milestones introduce their hazards in order without stacking',
    () {
      final game = BalanceGame()
        ..start(gameMode: GameMode.infinite)
        // Maze and snake encounters have their own tests; this one is about the
        // ordinary hazard scheduler.
        ..mazeSectionsEnabled = false
        ..snakeEncountersEnabled = false;
      game.maxHeight = 290;
      game.step(1 / 120);
      expect(game.specialHazards, isEmpty);
      final seen = <HazardKind>{};
      for (final height in [4500.0, 10800.0, 15000.0, 22500.0]) {
        game.maxHeight = height;
        for (var i = 0; i < 25 * 120; i++) {
          // Isolate scheduling from traps, ranged spiders and the idle penalty.
          game.board.clear();
          game.spiders.clear();
          game.webShots.clear();
          game.stallTime = 0;
          game.ballX = 332;
          game.velocity = 0;
          game.step(1 / 120);
          expect(game.specialHazards.length, lessThanOrEqualTo(1));
          seen.addAll(game.specialHazards.map((h) => h.kind));
        }
      }
      expect(seen, containsAll(HazardKind.values));
      expect(game.finished, isFalse);
    },
  );
  test(
    'special hazard pause, death and replay state are isolated from Classic',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      game.lives = 1;
      final h = SpecialHazard(
        HazardKind.platformGap,
        x: 180,
        y: 0,
        warningSeconds: .1,
      );
      game.specialHazards.add(h);
      game.setPaused(true);
      game.step(.1);
      expect(h.age, 0);
      game.setPaused(false);
      game.step(.1);
      game.step(.05);
      expect(game.phase, GamePhase.sinking);
      expect(game.fellThroughGap, isTrue);
      expect(game.message, contains('platform broke'));
      game.start(gameMode: GameMode.classic);
      expect(game.specialHazards, isEmpty);
      expect(game.fellThroughGap, isFalse);
      expect(game.lives, 3);
    },
  );
}
