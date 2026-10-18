import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';

void main() {
  testWidgets('review all Classic boards and representative live warnings', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'monospace']) {
      final font = FontLoader(family)
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
    }
    Directory('artifacts/classic-progression').createSync(recursive: true);
    for (var sheet = 0; sheet < 4; sheet++) {
      final recorder = ui.PictureRecorder();
      // Each board uses its actual renderer at 55% scale.
      final drawing = Canvas(recorder);
      drawing.drawColor(const Color(0xffe9ebdf), BlendMode.src);
      for (var panel = 0; panel < 20; panel++) {
        final n = sheet * 20 + panel + 1;
        final game = BalanceGame()..start(levelNumber: n);
        drawing.save();
        drawing.translate((panel % 5) * 214 + 8, (panel ~/ 5) * 338 + 24);
        final label = TextPainter(
          text: TextSpan(
            text: '$n  ${ClassicLevels.names[n - 1]}',
            style: const TextStyle(
              color: Color(0xff153c38),
              fontSize: 12,
              fontFamily: 'sans-serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 202);
        label.paint(drawing, const Offset(0, -20));
        drawing.scale(.55);
        BoardPainter(
          game,
          reducedMotion: true,
        ).paint(drawing, const Size(360, 560));
        drawing.restore();
      }
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(1070, 1352);
      await tester.runAsync(() async {
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/classic-progression/levels-${sheet * 20 + 1}-${sheet * 20 + 20}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      rendered.dispose();
      picture.dispose();
    }
    for (final n in [10, 20, 31, 38, 50, 51, 55, 60, 61, 66, 75, 80]) {
      final game = BalanceGame()..start(levelNumber: n),
          level = ClassicLevels.definition(n);
      if (level.hazards.isNotEmpty) {
        final wave = level.hazards.first;
        final position = wave.positions.first;
        final hazard = SpecialHazard(
          wave.kind,
          x: position.x,
          y: position.y,
          motion: wave.motion,
          orientation: wave.orientation,
          radiusX: wave.radiusX,
          radiusY: wave.radiusY,
          period: wave.period,
          phase: wave.phase,
          warningSeconds: wave.warningSeconds,
          liveSeconds: wave.liveSeconds,
        );
        hazard.step(1, 0);
        game.specialHazards.add(hazard);
      }
      for (final stage in [
        'warning',
        if (game.specialHazards.isNotEmpty) 'live',
      ]) {
        if (stage == 'live') {
          final hazard = game.specialHazards.single;
          hazard.step(hazard.warningSeconds - hazard.age + .6, 0);
        }
        final recorder = ui.PictureRecorder();
        final drawing = Canvas(recorder);
        BoardPainter(
          game,
          reducedMotion: true,
        ).paint(drawing, const Size(360, 560));
        final picture = recorder.endRecording(),
            image = await picture.toImage(360, 560);
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'artifacts/classic-progression/level-$n-$stage.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
        picture.dispose();
      }
    }
  });
}
