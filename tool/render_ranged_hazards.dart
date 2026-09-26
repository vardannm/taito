import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/spiders.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/spider_web.dart';

void main() {
  testWidgets('render Infinite web shots and circular holes', (tester) async {
    final font = FontLoader('monospace')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE7E7DE), BlendMode.src);
    for (var combo = 1; combo <= 2; combo++) {
      final game = BalanceGame(seed: 4)..start(gameMode: GameMode.infinite);
      game.survival.combo = 8;
      game.survival.visualCombo = 7 / 9;
      game.board.clear();
      game.coins.clear();
      game.survival.items.clear();
      game.spiders
        ..clear()
        ..addAll([
          BoardSpider(115, 205, 52),
          BoardSpider(245, 315, 45)..chasing = true,
        ]);
      final orbit = SpecialHazard(
        HazardKind.movingHole,
        x: 210,
        y: 115,
        motion: HazardMotion.circle,
        radiusX: 62,
        period: 5.5,
        liveSeconds: 6,
      );
      final web = SpiderWebShot(x: 105, y: 205, targetX: 180, targetY: 430);
      if (combo == 2) {
        orbit.step(2.8, 200);
        web.step(2.0);
      } else {
        web.step(.65);
      }
      game.specialHazards.add(orbit);
      game.webShots.add(web);
      game.lastCoinAge = .2;
      game.lastCoinX = 160;
      game.lastCoinY = 365;
      canvas.save();
      canvas.translate(((combo - 1) % 5) * 290.0, ((combo - 1) ~/ 5) * 485.0);
      final title = TextPainter(
        text: TextSpan(
          text: combo == 1 ? 'AIMING WARNING' : 'SLOW WEB + ORBIT',
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, const Offset(12, 5));
      canvas.translate(5, 30);
      BoardPainter(
        game,
        reducedMotion: true,
      ).paint(canvas, const Size(280, 440));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(580, 485);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/infinite-ranged-hazards.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    picture.dispose();
  });
}
