import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:balance_arcade/mode_previews.dart';

void main() {
  testWidgets('bake softened board screenshots for every selectable level', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'monospace']) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
    Directory('assets/mode_previews').createSync(recursive: true);
    for (final mode in [
      GameMode.infinite,
      GameMode.classic,
      GameMode.mazeEndless,
      GameMode.laserMaze,
      GameMode.merge2048,
    ]) {
      final count = mode == GameMode.classic
          ? ClassicLevels.count
          : mode == GameMode.laserMaze
          ? LaserMazeRoute.count
          : 1;
      for (var level = 1; level <= count; level++) {
        final game = BalanceGame(seed: 710 + level)
          ..start(gameMode: mode, levelNumber: level, waitForInput: true);
        final recording = ui.PictureRecorder();
        final canvas = Canvas(recording);
        canvas.scale(.5);
        // Softening is baked once; no runtime blur or game simulation is needed.
        canvas.saveLayer(
          const Rect.fromLTWH(0, 0, 360, 560),
          Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: .65, sigmaY: .65),
        );
        BoardPainter(
          game,
          reducedMotion: true,
        ).paint(canvas, const Size(360, 560));
        canvas.restore();
        final picture = recording.endRecording();
        final image = await picture.toImage(180, 280);
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            modePreviewAsset(mode, level),
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
        picture.dispose();
      }
    }
  });
}
