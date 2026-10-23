import 'dart:math' as math;

import 'package:balance_arcade/classic_levels.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Classic run whose board is replaced by [holes]; the ball rests at
/// (180, 493) on the flat launch platform.
BalanceGame boardWith(List<Hole> holes) {
  final game = BalanceGame()..start(levelNumber: 1);
  game.board
    ..clear()
    ..addAll(holes);
  return game;
}

void main() {
  test('holes without movement or breathing never change over time', () {
    for (final level in classicLevelDefinitions) {
      for (final hole in level.holes.where((h) => !h.animated)) {
        expect(identical(hole.at(12.5), hole), isTrue);
        if (hole.size == 1) expect(hole.extraReach, 0);
      }
    }
  });

  test('hole size scales the capture radius', () {
    final big = boardWith([const Hole(180, 478, target: 1, size: 2.5)]);
    big.step(1 / 60);
    expect(big.phase, GamePhase.sinking);
    expect(big.lastSuccess, isTrue);

    final normal = boardWith([const Hole(180, 478, target: 1)]);
    normal.step(1 / 60);
    expect(normal.phase, GamePhase.playing);

    final tiny = boardWith([const Hole(180, 489, target: 1, size: .2)]);
    tiny.step(1 / 60);
    expect(tiny.phase, GamePhase.playing, reason: '4 units > 8.5 × 0.2');
  });

  test('a moving target travels its path and captures the ball', () {
    const motion = HoleMotion(
      path: HazardMotion.horizontal,
      radiusX: 60,
      period: 2,
    );
    final game = boardWith([
      const Hole(140, 493, target: 1, motion: motion),
      const Hole(60, 100),
    ]);
    expect(game.board.first.x, 140);
    var seconds = 0.0;
    while (game.phase == GamePhase.playing && seconds < 2) {
      game.step(1 / 60);
      seconds += 1 / 60;
    }
    expect(game.phase, GamePhase.sinking);
    expect(game.lastSuccess, isTrue);
    // About a quarter of the way to the right edge of its sweep.
    expect(seconds, inInclusiveRange(.1, .5));
    expect(game.board.first.homeX, 140);
    expect(game.board[1].x, 60, reason: 'stationary holes never move');
    // The sinking ball follows the hole while it keeps moving.
    game.step(.1);
    expect(game.captureX, closeTo(game.board.first.x, .001));
  });

  test('moving holes animate before the first touch and freeze on pause', () {
    const motion = HoleMotion(path: HazardMotion.circle, radiusX: 30);
    final game = BalanceGame()..start(levelNumber: 1, waitForInput: true);
    game.board
      ..clear()
      ..add(const Hole(180, 200, target: 1, motion: motion));
    game.step(.5);
    final before = (game.board.first.x, game.board.first.y);
    expect(before, isNot((180.0 + 30, 200.0)));
    game.setPaused(true);
    game.step(.5);
    expect((game.board.first.x, game.board.first.y), before);
  });

  test('a breathing hole grows and shrinks for the whole level', () {
    const pulse = HolePulse(minSize: .4, maxSize: 2, period: 2);
    final game = boardWith([const Hole(60, 100, target: 1, pulse: pulse)]);
    final sizes = <double>[];
    for (var i = 0; i < 300; i++) {
      game.step(1 / 60);
      sizes.add(game.board.first.size);
    }
    // Five seconds: two and a half full breaths between the two sizes.
    expect(sizes.reduce(math.min), closeTo(.4, .01));
    expect(sizes.reduce(math.max), closeTo(2, .01));
    expect(game.board.first.x, 60, reason: 'breathing alone never moves it');
    expect(game.board.first.reach, closeTo(Hole.openingRadius * 2 + Hole.rimWidth, 1e-9));
    expect(pulse.sizeAt(0), .4);
    expect(pulse.sizeAt(1), closeTo(2, 1e-9));
  });

  test('a breathing hole catches the ball only while it is big', () {
    // 15 units away: inside 8.5 × 2 but outside 8.5 × 0.5.
    const pulse = HolePulse(minSize: .5, maxSize: 2, period: 2);
    final game = boardWith([const Hole(180, 478, target: 1, pulse: pulse)]);
    game.step(1 / 60);
    expect(game.phase, GamePhase.playing);
    var seconds = 1 / 60;
    while (game.phase == GamePhase.playing && seconds < 2) {
      game.step(1 / 60);
      seconds += 1 / 60;
    }
    expect(game.phase, GamePhase.sinking);
    expect(game.lastSuccess, isTrue);
    expect(seconds, inInclusiveRange(.4, .9));
  });

  test('stars and routes keep clear of a hole’s full reach', () {
    const moving = Hole(
      180,
      280,
      target: 0,
      size: 2,
      motion: HoleMotion(path: HazardMotion.circle, radiusX: 40),
    );
    expect(moving.reach, closeTo(Hole.openingRadius * 2 + Hole.rimWidth + 40, 1e-9));
    final targets = [
      for (var i = 0; i < 10; i++) Hole(50.0 + i * 26, 60.0 + i * 38, target: i + 1),
    ];
    final star = ClassicLevels.starFor([...targets, moving], []);
    final distance = math.sqrt(
      math.pow(star.x - 180, 2) + math.pow(star.y - 280, 2),
    );
    expect(distance, greaterThan(16 + moving.extraReach));
  });
}
