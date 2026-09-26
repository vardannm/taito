import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/porcupines.dart';

void main() {
  testWidgets('render porcupine warning and radial quills', (tester) async {
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
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE7E7DE), BlendMode.src);
    for (var panel = 0; panel < 3; panel++) {
      final game = BalanceGame(seed: 4)..start(gameMode: GameMode.infinite);
      game.board.clear();
      game.coins.clear();
      game.survival.items.clear();
      if (panel == 2) {
        game.survival.combo = 8;
        game.survival.visualCombo = 7 / 9;
      }
      final p = BoardPorcupine(180, 250, heading: .25);
      game.porcupines.add(p);
      if (panel == 0) {
        p.charge = .8;
      } else {
        game.quills.addAll(p.burst());
        for (final q in game.quills) {
          q.step(.85);
        }
      }
      canvas.save();
      canvas.translate(panel * 370.0, 0);
      final title = TextPainter(
        text: TextSpan(
          text: [
            'QUILLS RAISED',
            '360° RADIAL BURST',
            'HIGH COMBO CONTRAST',
          ][panel],
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      title.paint(canvas, const Offset(15, 12));
      canvas.translate(5, 40);
      BoardPainter(
        game,
        reducedMotion: true,
      ).paint(canvas, const Size(360, 560));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1110, 610);
    await tester.runAsync(() async {
      await Directory('artifacts').create(recursive: true);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/infinite-porcupines.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    picture.dispose();
  });
}
