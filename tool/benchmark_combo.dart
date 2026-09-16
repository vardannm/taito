import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/infinite_painter.dart';

void main() {
  testWidgets('sample combo frame recording and offscreen raster time', (
    tester,
  ) async {
    final results = <String, Object>{};
    await tester.runAsync(() async {
      for (final combo in [1, 4, 5]) {
        final game = BalanceGame(seed: 12)..start(gameMode: GameMode.infinite);
        game.maxHeight = 4500;
        game.survival.combo = combo;
        game.survival.visualCombo = (combo - 1) / 4;
        final record = <int>[], raster = <int>[];
        for (var i = 0; i < 32; i++) {
          game.clock = i / 60;
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(2);
          final watch = Stopwatch()..start();
          InfiniteBackdropPainter(
            game,
            reducedMotion: false,
          ).paint(canvas, const Size(390, 844));
          canvas.translate(0, 110);
          BoardPainter(game).paint(canvas, const Size(390, 600));
          final picture = recorder.endRecording();
          final recorded = watch.elapsedMicroseconds;
          watch.reset();
          final image = await picture.toImage(780, 1688);
          final rastered = watch.elapsedMicroseconds;
          watch.stop();
          if (i >= 8) {
            record.add(recorded);
            raster.add(rastered);
          }
          image.dispose();
          picture.dispose();
        }
        record.sort();
        raster.sort();
        results['combo$combo'] = {
          'recordMedianUs': record[record.length ~/ 2],
          'rasterMedianUs': raster[raster.length ~/ 2],
          'rasterP90Us': raster[(raster.length * .9).floor()],
          'samples': raster.length,
        };
      }
      const label = String.fromEnvironment(
        'BENCH_LABEL',
        defaultValue: 'current',
      );
      await File(
        'artifacts/combo-benchmark-$label.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    });
  });
}
