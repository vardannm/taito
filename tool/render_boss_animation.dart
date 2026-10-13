import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';

void main() {
  testWidgets('render all boss animations together', (tester) async {
    await (FontLoader('monospace')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final games = [
      for (final kind in BossKind.values)
        BalanceGame(seed: 4)
          ..start(gameMode: GameMode.infinite)
          ..boss = InfiniteBoss(kind: kind)
          ..board.clear()
          ..coins.clear()
          ..survival.items.clear(),
    ];
    await tester.runAsync(() async {
      await Directory(
        'artifacts/boss-animation-frames',
      ).create(recursive: true);
    });
    for (var frame = 0; frame < 84; frame++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFE7E7DE), BlendMode.src);
      for (var column = 0; column < games.length; column++) {
        final game = games[column];
        if (frame > 0) {
          for (var tick = 0; tick < 10; tick++) {
            game.boss!.step(
              1 / 120,
              target: (x: 180, y: game.screenY(game.ballY)),
            );
          }
        }
        canvas.save();
        canvas.translate(column * 300.0 + 6, 6);
        final title = TextPainter(
          text: TextSpan(
            text: game.boss!.displayName,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(canvas, Offset((288 - title.width) / 2, 0));
        title.dispose();
        canvas.translate(0, 24);
        canvas.scale(.8);
        BoardPainter(game).paint(canvas, const Size(360, 560));
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(games.length * 300, 484);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/boss-animation-frames/${frame.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      picture.dispose();
    }
  });
}
