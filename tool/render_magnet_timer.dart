import 'dart:io';
import 'dart:ui' as ui;

import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render magnet timer on light and dark boards', (tester) async {
    for (final family in ['sans-serif', 'monospace', 'MaterialIcons']) {
      final font = FontLoader(family);
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/${family == 'MaterialIcons' ? 'materialicons-regular.otf' : 'roboto-regular.ttf'}',
            ).readAsBytesSync(),
          ),
        ),
      );
      await font.load();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF102D2B), BlendMode.src);
    for (var index = 0; index < 6; index++) {
      final game = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
      game.cosmetic = index < 2 ? BallCosmetic.steel : BallCosmetic.nebula;
      if (index >= 4) game.ballX = index.isEven ? 24 : 336;
      game.survival.magnet = index.isEven ? 1 : 15;
      game.magnetDuration = 15;
      game.survival.visualCombo = index < 2 ? 0 : 1;
      canvas.save();
      canvas.translate((index % 2) * 360.0, (index ~/ 2) * 320.0);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 360, 320));
      canvas.translate(0, 170 - game.screenY(game.visualY));
      BoardPainter(
        game,
        reducedMotion: true,
        showHud: false,
      ).paint(canvas, const Size(360, 600));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final output = await picture.toImage(720, 960);
    await tester.runAsync(() async {
      final data = await output.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/magnet-timer-preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    });
    output.dispose();
    picture.dispose();
  });
}
