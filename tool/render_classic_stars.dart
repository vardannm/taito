import 'dart:io';
import 'dart:ui' as ui;

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
  testWidgets('render Classic star gameplay, four-star result and road', (
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

    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, width == 390 ? 844 : 568);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await selectWorld(tester, 1);
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      await capture('classic-star-board-${width.toInt()}');
      final star = game.levelStar!;
      game.ballX = star.x;
      game.left = game.right = star.y + BalanceGame.ballRadius;
      game.velocity = 0;
      await tester.pump(const Duration(milliseconds: 20));
      expect(profile.totalStars, 1);
      await capture('classic-star-collected-${width.toInt()}');
      game.won = true;
      game.completed = 10;
      game.phase = GamePhase.over;
      await tester.pump(const Duration(milliseconds: 20));
      await capture('classic-star-result-${width.toInt()}');
      final dynamic state = tester.state(find.byType(GameScreen));
      state.selectLevel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('classic-star-road-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
