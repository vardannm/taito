import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'game_test.dart' show advance;

void main() {
  test(
    'timed hazard coordinates come from level files, independently of hole edits',
    () {
      for (final level in [10, 20, 30, 50]) {
        final definition = ClassicLevels.definition(level);
        final waves = definition.hazards
            .where((wave) => wave.kind != HazardKind.movingHole)
            .toList();
        if (waves.isEmpty) continue;
        for (var target = 1; target <= 10; target++) {
          final game = BalanceGame()..start(levelNumber: level);
          game.board
            ..clear()
            ..add(Hole(320, 400, target: target));
          game.target = target;
          game.spiders.clear();
          game.coins.clear();
          // Remain clear of the side lasers on the later Classic boards.
          game.ballX = 50;
          for (var sequence = 0; sequence < 4; sequence++) {
            final wave = waves[sequence % waves.length];
            final choices = wave.positions
                .where((p) => p.target == target)
                .toList();
            final expected = choices[sequence % choices.length];
            game.specialHazards.removeWhere(
              (hazard) => hazard.kind != HazardKind.movingHole,
            );
            advance(
              game,
              (sequence == 0
                      ? definition.firstHazardAfter
                      : definition.hazardInterval) +
                  1 / 120,
            );
            final timed = game.specialHazards.where(
              (hazard) => hazard.kind != HazardKind.movingHole,
            );
            expect(timed, hasLength(1));
            final hazard = timed.single;
            expect(hazard.kind, wave.kind);
            expect((hazard.x, hazard.y), (expected.x, expected.y));
            expect(hazard.warningSeconds, wave.warningSeconds);
            expect(hazard.liveSeconds, wave.liveSeconds);
          }
        }
      }
    },
  );

  test(
    'moving holes keep their authored origin and persist across targets',
    () {
      for (final level in [20, 30, 50]) {
        final definition = ClassicLevels.definition(level);
        final waves = definition.hazards
            .where((wave) => wave.kind == HazardKind.movingHole)
            .toList();
        final game = BalanceGame()..start(levelNumber: level);
        final moving = game.specialHazards
            .where((hazard) => hazard.kind == HazardKind.movingHole)
            .toList();
        expect(moving, hasLength(waves.length));
        expect(moving, isNotEmpty);
        for (var i = 0; i < waves.length; i++) {
          final wave = waves[i];
          final origin = wave.positions.firstWhere((p) => p.target == 1);
          final hazard = moving[i];
          expect((hazard.originX, hazard.originY), (origin.x, origin.y));
          expect(hazard.active, isTrue);
          expect(hazard.liveSeconds, double.infinity);
          expect(hazard.motion, wave.motion);
          expect(hazard.period, wave.period);
        }
        game.ballX = 50;
        for (var target = 1; target <= 10; target++) {
          game.board
            ..clear()
            ..add(Hole(320, 400, target: target));
          game.target = target;
          final ages = moving.map((hazard) => hazard.age).toList();
          advance(game, .25);
          expect(game.phase, GamePhase.playing);
          for (var i = 0; i < moving.length; i++) {
            expect(game.specialHazards, contains(same(moving[i])));
            expect(moving[i].age, greaterThan(ages[i]));
            expect(moving[i].expired, isFalse);
          }
        }
      }
    },
  );

  test('restarting restores authored spiders without sharing live state', () {
    final game = BalanceGame()..start(levelNumber: 48);
    final original = game.spiders.first;
    original.x = 0;
    original.chasing = true;
    game.start(levelNumber: 48);
    expect(identical(original, game.spiders.first), isFalse);
    expect(game.spiders.first.chasing, isFalse);
    final authored = ClassicLevels.definition(48).spiders.first.create();
    expect(
      (game.spiders.first.x, game.spiders.first.y),
      (authored.x, authored.y),
    );
  });
}
