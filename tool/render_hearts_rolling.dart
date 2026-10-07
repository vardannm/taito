import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_painter.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/survival_upgrades.dart';

void main() {
  testWidgets('render six hearts and rolling artwork', (tester) async {
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
      final loader = FontLoader(family);
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/${family == 'MaterialIcons' ? 'materialicons-regular.otf' : 'roboto-regular.ttf'}',
            ).readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
    }
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false;
    p.survivalUpgrades[SurvivalUpgrade.hearts] = 3;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ArcadeApp(profile: p),
      ),
    );
    await tester.pump();
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    game.beginInput();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final shot =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    await tester.runAsync(() async {
      final png = await shot.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/six-hearts-hud.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFF2ECDD), BlendMode.src);
      final balls = [
        BallCosmetic.circuit,
        BallCosmetic.quasar,
        BallCosmetic.singularity,
      ];
      for (var row = 0; row < balls.length; row++) {
        for (var col = 0; col < 4; col++) {
          canvas.save();
          canvas.translate(70 + col * 140.0, 70 + row * 140.0);
          paintCosmetic(
            canvas,
            Offset.zero,
            42,
            balls[row],
            rotation: col * math.pi / 3,
            time: 1.0,
            reducedMotion: true,
          );
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(560, 420);
      final pngGrid = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/rolling-ball-artwork.png',
      ).writeAsBytes(pngGrid!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    shot.dispose();
  });
}
