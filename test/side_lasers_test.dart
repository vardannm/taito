import 'package:balance_arcade/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_test.dart' show advance;

BalanceGame clearBoard(int level, ControlMode control) {
  final game = BalanceGame()..setControlMode(control);
  game.start(levelNumber: level);
  game.board.clear();
  game.spiders.clear();
  game.specialHazards.clear();
  game.coins.clear();
  return game;
}

void main() {
  for (final control in ControlMode.values) {
    for (final right in [false, true]) {
      test(
        'level 31 side laser hits once on ${right ? 'right' : 'left'} with $control',
        () {
          final game = clearBoard(31, control);
          game.ballX = right ? 329 : 31;
          game.velocity = right ? 265 : -265;
          game.streak = 3;
          game.step(1 / 120);
          expect(game.lives, 2);
          expect(game.misses, 1);
          expect(game.streak, 0);
          expect(game.target, 1);
          expect(game.phase, GamePhase.sinking);
          expect(game.event, GameEvent.miss);
          expect(game.message, contains('Side laser hit'));
          expect(game.captureX, right ? 330 : 30);
          advance(game, .5);
          expect(game.lives, 2);
          advance(game, 1);
          expect(game.phase, GamePhase.playing);
          expect(game.ballX, 180);
        },
      );
    }
  }

  test('level 30 keeps safe edges; level 31 enables lethal rails', () {
    final game = clearBoard(30, ControlMode.twoFinger);
    game.ballX = 28;
    game.velocity = -265;
    game.step(1 / 120);
    expect(game.lives, 3);
    expect(game.phase, GamePhase.playing);
    expect(game.ballX, 28);
    expect(game.laserSideRails, isFalse);
    game.start(levelNumber: 31);
    expect(game.laserSideRails, isTrue);
    game.start(levelNumber: 80);
    expect(game.laserSideRails, isTrue);
    for (final mode in [
      GameMode.infinite,
      GameMode.daily,
      GameMode.practice,
      GameMode.merge2048,
    ]) {
      game.start(gameMode: mode);
      expect(game.laserSideRails, isFalse);
    }
  });

  test(
    'lasers leave a safe interior and respect pause and first-input wait',
    () {
      final game = clearBoard(31, ControlMode.oneFinger);
      for (final x in [30.1, 180.0, 329.9]) {
        game.ballX = x;
        game.velocity = 0;
        game.step(1 / 120);
        expect(game.lives, 3);
      }
      game.ballX = 28;
      game.setPaused(true);
      advance(game, .1);
      expect(game.lives, 3);
      game.setPaused(false);
      game.waitingForInput = true;
      advance(game, .1);
      expect(game.lives, 3);
    },
  );

  test('last life at a side laser ends the level after the hit animation', () {
    final game = clearBoard(31, ControlMode.twoFinger);
    game.lives = 1;
    game.ballX = 30;
    game.step(1 / 120);
    expect(game.lives, 0);
    advance(game, 1);
    expect(game.phase, GamePhase.over);
    expect(game.won, isFalse);
  });
}
