import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render Infinite waiting screen and held shield control', (
    tester,
  ) async {
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
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      for (final mode in ControlMode.values) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ArcadeApp(
              profile: PlayerProfile()
                ..sound = false
                ..haptics = false
                ..controlMode = mode,
            ),
          ),
        );
        await tester.pump();
        await capture('infinite-ready-${mode.name}-${size.width.toInt()}');
        if (mode == ControlMode.oneFinger) {
          final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
          final finger = await tester.startGesture(
            tester.getCenter(find.byType(OneFingerControls)),
          );
          await finger.moveBy(const Offset(12, -8));
          game.survival.items.add(
            InfiniteItem(InfiniteItemKind.shield, game.ballX, game.ballY),
          );
          await tester.pump(const Duration(milliseconds: 32));
          await capture('infinite-shield-held-${size.width.toInt()}');
          game.survival.shield = .01;
          await tester.pump(const Duration(milliseconds: 32));
          await finger.moveBy(const Offset(-4, -5));
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.controlHeld, isTrue);
          await capture('infinite-shield-expired-${size.width.toInt()}');
          game.board
            ..clear()
            ..add(Hole(game.ballX, game.ballY));
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.lives, 2);
          expect(game.controlHeld, isTrue);
          await capture('infinite-heart-held-${size.width.toInt()}');
          game.survival.recovery = 2.25;
          await tester.pump();
          await capture('infinite-heart-blink-${size.width.toInt()}');
          game.board.clear();
          game.survival.recovery = .01;
          await finger.moveBy(const Offset(0, -70));
          await tester.pump(const Duration(milliseconds: 32));
          expect(game.controlHeld, isTrue);
          await capture('infinite-heart-expired-${size.width.toInt()}');
          await finger.up();
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
