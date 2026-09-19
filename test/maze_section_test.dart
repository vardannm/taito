import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/maze_gates.dart';

/// Climbs a real Infinite run until its first laser maze section opens.
BalanceGame climbToMaze({int seed = 5}) {
  final game = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
  game.board.clear();
  for (var i = 0; i < 120 * 200 && !game.mazeSection; i++) {
    game.survival.shield = 100; // Survive the climb; this is not a dodge test.
    game.board.clear();
    game.stallTime = 0;
    game.step(1 / 120);
  }
  return game;
}

void main() {
  test('a laser maze section opens, runs a stretch of climb and closes', () {
    final game = climbToMaze();
    expect(game.mazeSection, isTrue);
    expect(game.metres, greaterThanOrEqualTo(InfiniteTuning.mazeFirstMetres));
    expect(game.hazardLabel, 'LASER MAZE');
    final opened = game.maxHeight / 10;

    // Gates arrive from above the board, spaced out, never all at once.
    var mostAtOnce = 0, frames = 0;
    final inFlight = <SpecialHazard>{};
    while (game.mazeSection) {
      game.survival.shield = 100;
      game.stallTime = 0;
      game.step(1 / 120);
      frames++;
      // The step that closes the section belongs to what comes after it.
      if (!game.mazeSection) break;
      mostAtOnce = mostAtOnce > game.mazeGates.length
          ? mostAtOnce
          : game.mazeGates.length;
      for (final gate in game.mazeGates) {
        expect(gate.gapWidth, greaterThanOrEqualTo(104));
        expect(gate.gapLeft, greaterThanOrEqualTo(MazeGate.edge));
        expect(gate.gapRight, lessThanOrEqualTo(MazeGate.edge + MazeGate.span));
      }
      // No fresh traps or hazards join the maze. Whatever was already in
      // flight when it opened may finish, but nothing new is scheduled.
      if (frames <= 2) {
        inFlight.addAll(game.specialHazards);
      } else {
        expect(game.specialHazards.every(inFlight.contains), isTrue);
      }
      expect(game.board, isEmpty);
      expect(
        game.maxHeight / 10 - opened,
        lessThan(InfiniteTuning.mazeSectionMetres + 2),
      );
    }
    expect(mostAtOnce, greaterThan(1));
    expect(
      game.maxHeight / 10 - opened,
      greaterThan(InfiniteTuning.mazeSectionMetres - 2),
    );
    // Holes resume immediately, with no backlog burst from the quiet stretch.
    for (var i = 0; i < 240; i++) {
      game.survival.shield = 100;
      game.step(1 / 120);
    }
    expect(game.board, isNotEmpty);
    expect(game.board.length, lessThanOrEqualTo(48));
  });

  test('a beam is lethal outside its gap and safe inside it', () {
    final gate = MazeGate(y: 300, gapCenter: 180, gapWidth: 120)
      ..step(MazeGate.fadeIn, 0);
    expect(gate.intensity, 1);
    // Straight through the opening.
    expect(gate.contact(180, 260, 180, 340, 7), isNull);
    // Into the beam either side of it.
    expect(gate.contact(90, 260, 90, 340, 7), isNotNull);
    expect(gate.contact(300, 260, 300, 340, 7), isNotNull);
    // Clipping the edge of the opening counts as a hit.
    expect(gate.contact(gate.gapLeft - 2, 260, gate.gapLeft - 2, 340, 7),
        isNotNull);
    // Crossing sideways along the beam's own line.
    expect(gate.contact(60, 300, 320, 300, 7), isNotNull);
    // Nowhere near it.
    expect(gate.contact(180, 100, 180, 150, 7), isNull);
  });

  test('a fresh beam cannot flash on top of the ball', () {
    final gate = MazeGate(y: 300, gapCenter: 40, gapWidth: 110);
    expect(gate.intensity, 0);
    expect(gate.contact(180, 295, 180, 305, 7), isNull);
    gate.step(MazeGate.fadeIn / 2, 0);
    expect(gate.contact(180, 295, 180, 305, 7), isNull);
    gate.step(MazeGate.fadeIn, 0);
    expect(gate.contact(180, 295, 180, 305, 7), isNotNull);
  });

  test('a maze section costs a heart on contact, not the run', () {
    final game = climbToMaze(seed: 9);
    game.survival.shield = 0;
    game.survival.recovery = 0;
    final lives = game.lives;
    game.mazeGates
      ..clear()
      ..add(MazeGate(y: game.screenY(game.ballY), gapCenter: 30, gapWidth: 110)
        ..step(MazeGate.fadeIn, 0));
    game.step(1 / 120);
    expect(game.lives, lives - 1);
    expect(game.phase, GamePhase.playing);
    expect(game.survival.notice, contains('LIFE LOST'));
    expect(game.survival.combo, 1);
  });
}
