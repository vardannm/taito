import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_test.dart' show advance;

void main() {
  test(
    'moving holes appear and move before the first input in every authored level',
    () {
      for (var level = 1; level <= ClassicLevels.count; level++) {
        final waves = ClassicLevels.definition(
          level,
        ).hazards.where((w) => w.kind == HazardKind.movingHole).toList();
        final game = BalanceGame()
          ..start(levelNumber: level, waitForInput: true);
        expect(
          game.specialHazards,
          hasLength(waves.length),
          reason: 'Level $level',
        );
        final positions = game.specialHazards.map((h) => (h.x, h.y)).toList();
        advance(game, .5);
        for (var i = 0; i < waves.length; i++) {
          final hole = game.specialHazards[i];
          expect(hole.active, isTrue);
          expect((hole.x, hole.y), isNot(positions[i]));
        }
        expect(game.elapsed, 0);
        expect(game.lives, 3);
        expect(game.waitingForInput, isTrue);
      }
    },
  );

  test(
    'moving holes persist through targets and returns, freeze on pause, and reset on replay',
    () {
      final game = BalanceGame()..start(levelNumber: 54);
      final holes = List<SpecialHazard>.of(game.specialHazards);
      game.board.clear();
      game.coins.clear();
      game.ballX = 30;
      advance(game, 30);
      expect(game.specialHazards, orderedEquals(holes));
      expect(holes.every((h) => h.active), isTrue);
      final age = holes.first.age;
      game.setPaused(true);
      advance(game, 1);
      expect(holes.first.age, age);
      game.setPaused(false);
      game.target = 2;
      game.phase = GamePhase.sinking;
      game.phaseTime = 0;
      advance(game, 1.5);
      expect(game.specialHazards, orderedEquals(holes));
      expect(holes.first.age, greaterThan(age + 1));
      expect(game.phase, GamePhase.playing);
      game.start(levelNumber: 54);
      expect(game.specialHazards, hasLength(2));
      expect(game.specialHazards.first, isNot(same(holes.first)));
      expect(game.specialHazards.first.age, 0);
    },
  );

  test('persistent holes do not block the timed laser waves', () {
    final game = BalanceGame()..start(levelNumber: 52);
    game.board.clear();
    game.coins.clear();
    game.ballX = 30;
    advance(game, ClassicLevels.definition(52).firstHazardAfter + .1);
    expect(
      game.specialHazards.where((h) => h.kind == HazardKind.movingHole),
      hasLength(1),
    );
    expect(
      game.specialHazards.where((h) => h.kind == HazardKind.laser),
      hasLength(1),
    );
  });
}
