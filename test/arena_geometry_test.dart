import 'dart:ui' as ui;
import 'package:balance_arcade/arena_canvas.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/maze_gates.dart';
import 'package:balance_arcade/merge.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'projected positions spread while circles and local sprite shapes stay round',
    () async {
      final recorder = ui.PictureRecorder();
      final raw = Canvas(recorder);
      final arena = ArenaCanvas(raw, 3);
      arena.drawCircle(const Offset(20, 20), 7, Paint()..color = Colors.white);
      arena.actor(const Offset(40, 20), (canvas) {
        canvas.drawCircle(Offset.zero, 7, Paint()..color = Colors.white);
      });
      final picture = recorder.endRecording();
      final image = await picture.toImage(160, 40);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int alpha(int x, int y) => data.getUint8((y * 160 + x) * 4 + 3);
      for (final x in [60, 120]) {
        expect(alpha(x, 20), 255);
        expect(alpha(x + 6, 20), greaterThan(0));
        expect(alpha(x, 26), greaterThan(0));
        expect(alpha(x + 9, 20), 0);
        expect(alpha(x, 29), 0);
      }
      image.dispose();
      picture.dispose();
    },
  );

  test(
    'wide holes use the visible circle rather than an enlarged horizontal hitbox',
    () {
      for (final stretch in [1.0, 3.0]) {
        final game = BalanceGame()..start(gameMode: GameMode.practice);
        game.arenaStretch = stretch;
        game.left = game.right = 440;
        game.ballX = 180;
        game.board
          ..clear()
          ..add(Hole(184, game.ballY, target: 1));
        game.step(1 / 120);
        expect(game.phase == GamePhase.sinking, stretch == 1);
      }
    },
  );

  test('Merge food keeps a circular contact footprint in the wider arena', () {
    for (final stretch in [1.0, 3.0]) {
      final run = MergeRun(seed: 3)..arenaStretch = stretch;
      run.orbs
        ..clear()
        ..add(NumberOrb(192, 300, 2));
      run.step(1 / 120, 180, 300, 180, 300);
      expect(run.collected, stretch == 1 ? 1 : 0);
    }
  });

  test('maze openings account for the unscaled ball radius', () {
    for (final stretch in [1.0, 3.0]) {
      final gate = MazeGate(y: 300, gapCenter: 180, gapWidth: 10)
        ..arenaStretch = stretch;
      gate.step(1, 0);
      expect(gate.contact(180, 295, 180, 305, 7) == null, stretch == 3);
    }
  });

  test('spider territories use physical spacing on wide layouts', () {
    for (final stretch in [1.0, 3.0]) {
      final spider = BoardSpider(186, 300, 1)..arenaStretch = stretch;
      spider.step(1 / 120, 180, 300, 180, 300);
      expect(spider.chasing, stretch == 1);
    }
  });

  test('side lasers contact the ball at the visible rail boundary', () {
    for (final stretch in [1.0, 3.0]) {
      final game = BalanceGame()
        ..start(gameMode: GameMode.classic, levelNumber: 31);
      game.arenaStretch = stretch;
      game.board.clear();
      game.spiders.clear();
      game.specialHazards.clear();
      game.left = game.right = 400;
      game.ballX = 24;
      game.step(1 / 120);
      expect(game.lives, stretch == 1 ? 2 : 3);
    }
  });

  test(
    'swept circle contacts and rail endpoints share the same arena metric',
    () {
      final view = BoardViewport(
        const Size(1920, 1080),
        fillWidth: 1,
        bottomInset: 96,
      );
      expect(
        view.project(const Offset(340, 0)).dx -
            view.project(const Offset(20, 0)).dx,
        closeTo(1920 * .74, .001),
      );
      expect(
        circleContact(175, 300, 185, 300, 180, 300, 7, xScale: 3),
        closeTo(8 / 30, .00001),
      );
    },
  );
}
