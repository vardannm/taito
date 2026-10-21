import 'dart:io';
import 'dart:ui' as ui;

import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../test/infinite_revive_test.dart' show FakeReviveAds, loseLastHeart;
import '../test/support/mode_navigation.dart' show startWorld;

void main() {
  testWidgets('render settings and revive coin summary on phones', (
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
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false
        ..wallet = 785;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: p, reviveAds: FakeReviveAds()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('settings-fixed-${width.toInt()}');
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.survival.points = 1278;
      game.maxHeight = 780;
      game.coinsCollected = 37;
      await loseLastHeart(tester, game);
      await capture('revive-coins-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
