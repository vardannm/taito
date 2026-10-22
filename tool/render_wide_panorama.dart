import 'dart:io';
import 'dart:ui' as ui;

import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../test/support/mode_navigation.dart';

void main() {
  testWidgets('render panoramic gameplay in every mode', (tester) async {
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/${family == 'MaterialIcons' ? 'materialicons-regular.otf' : 'roboto-regular.ttf'}',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/panorama-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    for (final (name, size, cosmetic) in [
      ('phone', const Size(390, 844), BallCosmetic.steel),
      ('duo', const Size(1114, 720), BallCosmetic.steel),
      ('desktop', const Size(1920, 1080), BallCosmetic.steel),
      ('nebula', const Size(1114, 720), BallCosmetic.nebula),
    ]) {
      tester.view.physicalSize = size;
      for (final mode in GameMode.values) {
        final profile = PlayerProfile()
          ..tutorialSeen = true
          ..selectedBall = cosmetic
          ..music = false
          ..sound = false
          ..haptics = false;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ArcadeApp(profile: profile),
          ),
        );
        await tester.pump();
        if ([
          GameMode.infinite,
          GameMode.classic,
          GameMode.merge2048,
        ].contains(mode)) {
          await selectWorld(
            tester,
            mode == GameMode.infinite
                ? 0
                : mode == GameMode.classic
                ? 1
                : 2,
          );
          await startWorld(tester);
        } else {
          final dynamic state = tester.state(find.byType(GameScreen));
          state.start(
            mode,
            challengeDate: mode == GameMode.daily
                ? DateTime.utc(2026, 10, 22)
                : null,
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull, reason: '$name $mode');
        await capture('$name-${mode.name}');
        if (mode == GameMode.infinite && name != 'phone') {
          final dynamic state = tester.state(find.byType(GameScreen));
          final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
          game.survival.combo = 10;
          game.survival.visualCombo = 1;
          game.survival.points = 4201;
          game.score = 4201;
          game.survival.announce('LASER MAZE · steer through the gaps');
          game.left = 440;
          game.right = 475;
          state.hud.value = Object();
          state.frame.value++;
          await tester.pump();
          await capture('$name-max-combo');
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
