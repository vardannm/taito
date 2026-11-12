import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazard_painter.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_test.dart' show advance;
import 'hud_laser_bounds_test.dart' show BeamCanvas;

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1024, 1366),
    const Size(1366, 1024),
  ]) {
    test('level 24 laser clears the launch platform at $size', () {
      final game = BalanceGame()..start(levelNumber: 24);
      game.board
        ..clear()
        ..add(const Hole(40, 100, target: 1));
      game.coins.clear();
      game.ballX = 224; // Directly under the first authored beam.
      final view = BoardViewport.forGame(size, game, fillWidth: 1);
      game.arenaStretch = view.stretch;
      advance(game, 5.1);
      final laser = game.specialHazards.single;
      final warning = BeamCanvas();
      paintSpecialHazards(warning, game, true);
      expect(warning.rectangles.single.bottom, SpecialHazard.startClearBottom);
      advance(game, 2.6);
      expect(laser.active, isTrue);
      expect(game.lives, 3);
      expect(game.phase, GamePhase.playing);
      expect(laser.hits(224, 493, 224, 493), isFalse);
      expect(laser.hits(210, 450, 240, 450), isTrue);
      final live = BeamCanvas();
      paintSpecialHazards(live, game, true);
      final beam = live.lines.first;
      expect(beam.$2.dy, SpecialHazard.startClearBottom);
      final bottom = view.project(beam.$2).dy;
      final launch = view.project(Offset(224, game.ballY)).dy;
      // Includes the lower emitter (6 units) and the ball radius.
      expect(
        launch - bottom,
        greaterThan((6 + BalanceGame.ballRadius) * view.scale),
      );
    });
  }
}
