import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'hazard coordinates come from level files, independently of hole edits',
    () {
      for (final level in [10, 20, 30, 50]) {
        final definition = ClassicLevels.definition(level);
        for (var target = 1; target <= 10; target++) {
          final game = BalanceGame()..start(levelNumber: level);
          game.board
            ..clear()
            ..add(Hole(320, 400, target: target));
          game.target = target;
          game.spiders.clear();
          game.coins.clear();
          game.ballX = 30;
          for (var sequence = 0; sequence < 4; sequence++) {
            final wave =
                definition.hazards[sequence % definition.hazards.length];
            final choices = wave.positions
                .where((p) => p.target == target)
                .toList();
            final expected = choices[sequence % choices.length];
            game.specialHazards.clear();
            game.legTime =
                definition.firstHazardAfter +
                sequence * (definition.hazardInterval + 1);
            game.step(1 / 120);
            expect(game.specialHazards, hasLength(1));
            final hazard = game.specialHazards.single;
            expect(hazard.kind, wave.kind);
            expect((hazard.x, hazard.y), (expected.x, expected.y));
            expect(hazard.warningSeconds, wave.warningSeconds);
            expect(hazard.liveSeconds, wave.liveSeconds);
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
