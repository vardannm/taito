import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/late_enemies.dart';
import 'package:balance_arcade/late_enemy_painter.dart';
import '../test/combo_render_budget_test.dart' show DrawingBudget;

void main() {
  testWidgets('render animated late enemy preview and report drawing work', (
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
    const names = ['BEETLE', 'CRICKET', 'MOTH', 'SCORPION', 'SEED SPITTER'];
    final output = Directory('artifacts/enemy-motion');
    await tester.runAsync(() => output.create(recursive: true));
    final maxDraws = <LateEnemyKind, int>{};
    const measureOnly = bool.fromEnvironment('GILT_ENEMY_MEASURE_ONLY');
    for (var frame = 0; frame < 72; frame++) {
      final age = .3 + frame / 24;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFF2ECDD), BlendMode.src);
      for (final kind in LateEnemyKind.values) {
        final game = BalanceGame()..start(gameMode: GameMode.infinite);
        game.lateEnemy = LateEnemyEncounter(
          kind: kind,
          origin: (x: 180, y: 160),
          target: (x: 210, y: 420),
        )..step(age);
        final budget = DrawingBudget();
        paintLateEnemy(budget, game, false);
        maxDraws[kind] = math.max(maxDraws[kind] ?? 0, budget.draws);
        if (measureOnly) continue;
        canvas.save();
        canvas.translate(kind.index * 200.0, 0);
        final label = TextPainter(
          text: TextSpan(
            text: names[kind.index],
            style: const TextStyle(
              color: Color(0xFF20282A),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(100 - label.width / 2, 16));
        label.dispose();
        canvas.clipRect(const Rect.fromLTWH(5, 40, 190, 185));
        canvas.translate(100, 135);
        canvas.scale(2.5);
        canvas.translate(-180, -160);
        paintLateEnemy(canvas, game, false);
        canvas.restore();
      }
      final picture = recorder.endRecording();
      if (measureOnly) {
        picture.dispose();
        continue;
      }
      final image = await picture.toImage(1000, 230);
      await tester.runAsync(() async {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/frame-${frame.toString().padLeft(3, '0')}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
      image.dispose();
      picture.dispose();
    }
    for (final entry in maxDraws.entries) {
      // Preview measurements include warnings and every live projectile.
      // ignore: avoid_print
      print(
        '${entry.key.name}: ${entry.value} peak draws, 0 blur/layer passes',
      );
    }
  });
}
