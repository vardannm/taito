import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/late_enemies.dart';

void main() {
  testWidgets('render all five late enemies, warnings and live attacks', (
    tester,
  ) async {
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
    for (var row = 0; row < 3; row++) {
      for (final kind in LateEnemyKind.values) {
        final game = BalanceGame(seed: 4)..start(gameMode: GameMode.infinite);
        game.board.clear();
        game.coins.clear();
        game.survival.items.clear();
        if (row == 2) {
          game.survival.combo = 8;
          game.survival.visualCombo = 7 / 9;
        }
        final e = LateEnemyEncounter(
          kind: kind,
          origin: (x: kind == LateEnemyKind.moth ? 180 : 60, y: 155),
          target: (x: 210, y: 390),
        );
        game.lateEnemy = e;
        e.step(
          row == 0
              ? .7
              : row == 1
              ? 1.8
              : 2.6,
        );
        canvas.save();
        canvas.translate(kind.index * 370.0 + 5, row * 610.0);
        final title = TextPainter(
          text: TextSpan(
            text:
                '${kind.name}\n${['WARNING', 'IN FLIGHT', 'LATE / HIGH COMBO'][row]}',
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 350);
        title.paint(canvas, const Offset(10, 7));
        title.dispose();
        canvas.translate(0, 43);
        BoardPainter(
          game,
          reducedMotion: true,
        ).paint(canvas, const Size(360, 560));
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1850, 1830);
    await tester.runAsync(() async {
      await Directory('artifacts').create(recursive: true);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/infinite-late-enemies.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    picture.dispose();
  });
}
