import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_world.dart';
import 'package:balance_arcade/ball_painter.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> writeImage(ui.Image image, String name) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('artifacts/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render all ball worlds, dark gameplay and the small-phone shop', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'monospace', 'Roboto']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final recorder = ui.PictureRecorder();
    // Each card is the same renderer used in play, with no hand-drawn mockups.
    final c = Canvas(recorder);
    c.drawColor(const Color(0xFFF2ECDD), BlendMode.src);
    for (final ball in BallCosmetic.values) {
      final x = (ball.index % 5) * 220.0 + 10,
          y = (ball.index ~/ 5) * 320.0 + 10;
      final area = Rect.fromLTWH(x, y, 200, 258);
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(14)));
      paintBallWorld(c, area, ball, reducedMotion: true);
      paintCosmetic(c, area.center, 25, ball, reducedMotion: true);
      c.restore();
      final text = TextPainter(
        text: TextSpan(
          text: '${ball.label}\n${BallWorld.of(ball).name}',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF163D3B),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200);
      text.paint(c, Offset(x + 2, y + 265));
    }
    final picture = recorder.endRecording();
    await tester.runAsync(
      () async =>
          writeImage(await picture.toImage(1100, 1280), 'ball-worlds-gallery'),
    );
    picture.dispose();
    // Exercise every game mode against dark scenery.
    final modes = [GameMode.infinite, GameMode.classic, GameMode.merge2048];
    final modeRecorder = ui.PictureRecorder();
    final modeCanvas = Canvas(modeRecorder);
    for (var i = 0; i < modes.length; i++) {
      final g = BalanceGame(seed: 3)
        ..cosmetic = BallCosmetic.singularity
        ..start(gameMode: modes[i], waitForInput: true);
      modeCanvas.save();
      modeCanvas.translate(i * 360.0, 0);
      BoardPainter(
        g,
        reducedMotion: true,
      ).paint(modeCanvas, const Size(360, 560));
      modeCanvas.restore();
    }
    final modesPicture = modeRecorder.endRecording();
    await tester.runAsync(
      () async => writeImage(
        await modesPicture.toImage(modes.length * 360, 560),
        'ball-worlds-all-modes',
      ),
    );
    modesPicture.dispose();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..controlMode = ControlMode.boardTilt
      ..selectedBall = BallCosmetic.singularity;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ArcadeApp(profile: profile),
      ),
    );
    await tester.pump();
    final initialRender =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(
      () async => writeImage(
        await initialRender.toImage(pixelRatio: 2),
        'board-tilt-idle',
      ),
    );
    final touch = await tester.startGesture(
      tester.getCenter(find.byType(PivotBoard)),
    );
    await touch.moveBy(const Offset(12, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    var render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(
      () async => writeImage(
        await render.toImage(pixelRatio: 2),
        'ball-worlds-gameplay',
      ),
    );
    await touch.up();
    await tester.pump();
    await tester.runAsync(
      () async => writeImage(
        await render.toImage(pixelRatio: 2),
        'board-tilt-released',
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: cream,
            body: BallShop(profile: profile),
          ),
        ),
      ),
    );
    await tester.pump();
    render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(
      () async =>
          writeImage(await render.toImage(pixelRatio: 2), 'ball-worlds-shop'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
