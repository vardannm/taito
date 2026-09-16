import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import '../test/start_flow_test.dart' show contact;

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render expansion reversal and floating heart feedback', (
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
      for (final control in ControlMode.values) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ArcadeApp(
              profile: PlayerProfile()
                ..sound = false
                ..haptics = false
                ..controlMode = control,
            ),
          ),
        );
        await tester.pump();
        final dynamic state = tester.state(find.byType(GameScreen));
        final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
        final prefix = 'enter-${control.name}-${size.width.toInt()}';
        await capture('$prefix-preview');
        final finger = await tester.startGesture(
          contact(tester, game),
          pointer: 81,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await capture('$prefix-middle');
        await tester.pump(const Duration(milliseconds: 260));
        await capture('$prefix-expanded-with-chrome');
        await tester.pump(const Duration(milliseconds: 160));
        await capture('$prefix-playing');
        game.board
          ..clear()
          ..add(Hole(game.ballX, game.ballY));
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.lives, 2);
        expect(state.heartEffects, hasLength(1));
        await capture('$prefix-heart-spawn');
        await tester.pump(const Duration(milliseconds: 260));
        await capture('$prefix-heart-float');
        await tester.pump(const Duration(milliseconds: 650));
        expect(state.heartEffects, isEmpty);
        await capture('$prefix-heart-gone');
        await finger.up();
        state.home();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await capture('$prefix-shrinking');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await capture('$prefix-returned');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
