import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/late_enemy_painter.dart';

void main() {
  testWidgets('render scorpion skin at detail and gameplay scale', (
    tester,
  ) async {
    await (FontLoader('preview')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/Roboto-Regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFF2ECDD), BlendMode.src);
    for (var panel = 0; panel < 3; panel++) {
      final game = BalanceGame(seed: 4)..start(gameMode: GameMode.infinite);
      game.board.clear();
      game.coins.clear();
      game.survival.items.clear();
      if (panel == 2) {
        game.survival.combo = 8;
        game.survival.visualCombo = 7 / 9;
      }
      final enemy = LateEnemyEncounter(
        kind: LateEnemyKind.scorpion,
        origin: (x: 85, y: 155),
        target: (x: 210, y: 390),
      )..step(panel == 0 ? .8 : 1.8);
      game.lateEnemy = enemy;
      canvas.save();
      canvas.translate(panel * 360.0, 0);
      final background = panel == 2
          ? const Color(0xFF18264D)
          : const Color(0xFFF2ECDD);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 360, 310),
        Paint()..color = background,
      );
      final label = TextPainter(
        text: TextSpan(
          text: ['AIMING', 'FIRING', 'HIGH COMBO'][panel],
          style: TextStyle(
            fontFamily: 'preview',
            fontSize: 15,
            letterSpacing: 2,
            color: panel == 2 ? Colors.white : const Color(0xFF382E36),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(180 - label.width / 2, 22));
      label.dispose();
      canvas.save();
      canvas.clipRect(const Rect.fromLTWH(12, 55, 336, 245));
      canvas.translate(180, 180);
      canvas.scale(3);
      canvas.translate(-85, -155);
      paintLateEnemy(canvas, game, false);
      canvas.restore();
      canvas.translate(45, 330);
      canvas.scale(.75);
      BoardPainter(
        game,
        reducedMotion: true,
      ).paint(canvas, const Size(360, 560));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1080, 780);
    await tester.runAsync(() async {
      await Directory('artifacts').create(recursive: true);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      const version = String.fromEnvironment(
        'SCORPION_PREVIEW',
        defaultValue: 'after',
      );
      await File(
        'artifacts/scorpion-skin-$version.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    picture.dispose();
  });
}
