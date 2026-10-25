import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/pivot_board.dart';

void main() {
  testWidgets('render offset handles with the ball at each end', (
    tester,
  ) async {
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
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = BalanceGame()
      ..start(gameMode: GameMode.infinite)
      ..board.clear();
    final frame = ValueNotifier(0);
    final boundary = GlobalKey();
    for (final scene in ['left', 'right', 'bottom']) {
      game.left = scene == 'bottom' ? 526 : 440;
      game.right = scene == 'bottom' ? 526 : 390;
      game.ballX = scene == 'right' ? 332 : 28;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: PivotBoard(game: game, frame: frame, fillWidth: 1),
          ),
        ),
      );
      frame.value++;
      await tester.pump(const Duration(milliseconds: 32));
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/two-finger').create(recursive: true);
        await File(
          'artifacts/two-finger/$scene.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
    frame.dispose();
  });
}
