import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/rewards.dart';
import '../test/support/mode_navigation.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render the five carousel worlds and control layouts', (
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
        final profile = PlayerProfile()
          ..sound = false
          ..haptics = false
          ..classicLevel = 18
          ..mazeLevel = 12
          ..controlMode = control;
        for (var i = 1; i <= 17; i++) {
          profile.levelRecords[profile.recordKey(i, control)] =
              const LevelRecord(starMask: 7);
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ArcadeApp(profile: profile),
          ),
        );
        await tester.pump();
        for (var index = 0; index < 5; index++) {
          await selectWorld(tester, index);
          await capture(
            'carousel-$index-${control.name}-${size.width.toInt()}',
          );
        }
        // A real halfway swipe, with both environments and the title transition.
        final gesture = await tester.startGesture(const Offset(100, 100));
        await gesture.moveBy(Offset(size.width * .45, 0));
        await tester.pump();
        await capture(
          'carousel-transition-${control.name}-${size.width.toInt()}',
        );
        await gesture.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await startWorld(tester);
        await tester.pump(const Duration(milliseconds: 250));
        await capture('carousel-playing-${control.name}-${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
