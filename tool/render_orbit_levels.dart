import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/board_painter.dart';

void main() {
  testWidgets('render new orbit and laser patterns', (tester) async {
    final recording = ui.PictureRecorder();
    final canvas = Canvas(recording);
    canvas.drawColor(const Color(0xffe9ebdf), BlendMode.src);
    var panel = 0;
    for (final sample in [
      (51, 0, false),
      (58, 0, false),
      (63, 0, true),
      (68, 0, true),
      (80, 0, true),
      (80, 3, false),
    ]) {
      final game = BalanceGame()..start(levelNumber: sample.$1);
      final wave = ClassicLevels.definition(sample.$1).hazards[sample.$2];
      final p = wave.positions.first;
      final hazard = SpecialHazard(
        wave.kind,
        x: p.x,
        y: p.y,
        motion: wave.motion,
        orientation: wave.orientation,
        radiusX: wave.radiusX,
        radiusY: wave.radiusY,
        period: wave.period,
        phase: wave.phase,
        warningSeconds: wave.warningSeconds,
        liveSeconds: wave.liveSeconds,
      );
      hazard.step(sample.$3 ? wave.warningSeconds + .6 : 1, 0);
      game.specialHazards.add(hazard);
      canvas.save();
      canvas.translate((panel % 3) * 380 + 10, (panel ~/ 3) * 590 + 20);
      BoardPainter(
        game,
        reducedMotion: true,
      ).paint(canvas, const Size(360, 560));
      canvas.restore();
      panel++;
    }
    final picture = recording.endRecording();
    final image = await picture.toImage(1140, 1180);
    await tester.runAsync(() async {
      Directory('artifacts').createSync(recursive: true);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/orbit_levels.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    picture.dispose();
  });
}
