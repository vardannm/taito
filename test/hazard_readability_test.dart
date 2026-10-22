import 'dart:math' as math;
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_world.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazard_painter.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/spider_painter.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WarningCanvas implements Canvas {
  final arrows = <Color>[];
  final legs = <Color>[];
  @override
  void drawPath(Path path, Paint paint) {
    if (paint.color.withAlpha(255) == const Color(0xFFFFDA82)) {
      arrows.add(paint.color);
    } else {
      legs.add(paint.color);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('moving lasers blink directional cues only before activation', () {
    final game = BalanceGame()..start(gameMode: GameMode.practice);
    final moving = SpecialHazard(
      HazardKind.laser,
      x: 180,
      y: 90,
      sweeping: true,
    );
    game.specialHazards.add(moving);
    final bright = WarningCanvas();
    paintSpecialHazards(bright, game, false);
    expect(bright.arrows.length, 6);
    expect(bright.arrows.first.a, 1);
    moving.age = .3;
    final dim = WarningCanvas();
    paintSpecialHazards(dim, game, false);
    expect(dim.arrows.first.a, lessThan(.5));
    final reducedMotion = WarningCanvas();
    paintSpecialHazards(reducedMotion, game, true);
    expect(reducedMotion.arrows.first.a, 1);
    moving.step(2, 0);
    final live = WarningCanvas();
    paintSpecialHazards(live, game, false);
    expect(live.arrows, isEmpty);
    game.specialHazards
      ..clear()
      ..add(SpecialHazard(HazardKind.laser, x: 180, y: 90));
    final fixed = WarningCanvas();
    paintSpecialHazards(fixed, game, false);
    expect(fixed.arrows, isEmpty);
  });

  test(
    'direction cue agrees with initial motion, including turning points',
    () {
      for (final motion in [
        HazardMotion.horizontal,
        HazardMotion.vertical,
        HazardMotion.circle,
        HazardMotion.oval,
      ]) {
        for (final phase in [0.0, math.pi / 2, math.pi]) {
          final hazard = SpecialHazard(
            HazardKind.laser,
            x: 180,
            y: 200,
            motion: motion,
            phase: phase,
          );
          final direction = hazard.laserWarningDirection!;
          final oldX = hazard.x, oldY = hazard.y;
          hazard.step(hazard.warningSeconds + .001, 0);
          final dot =
              (hazard.x - oldX) * direction.x + (hazard.y - oldY) * direction.y;
          expect(dot, greaterThan(0), reason: '$motion at $phase');
        }
      }
    },
  );

  test(
    'starting world spiders contrast against the dark field in every mode',
    () {
      final game = BalanceGame()..cosmetic = BallCosmetic.steel;
      for (final mode in GameMode.values) {
        game.start(gameMode: mode);
        game.spiders
          ..clear()
          ..add(BoardSpider(180, 280, 45));
        final canvas = WarningCanvas();
        paintSpiders(canvas, game, true);
        expect(canvas.legs, isNotEmpty);
        final light = canvas.legs.first.computeLuminance();
        for (final background in BallWorld.of(BallCosmetic.steel).field) {
          expect(
            (light + .05) / (background.computeLuminance() + .05),
            greaterThan(7),
          );
        }
      }
    },
  );
}
