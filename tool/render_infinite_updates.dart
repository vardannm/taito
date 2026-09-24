import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../test/support/mode_navigation.dart';

void main() {
  testWidgets('centered Infinite HUD and rewards during magnet attraction', (
    tester,
  ) async {
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
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, width == 390 ? 844 : 568);
      final key = GlobalKey();
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      await profile.grantBallTestCoins();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await startWorld(tester);
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      g.board.clear();
      g.coins.clear();
      g.survival.items.clear();
      g.survival.combo = 10;
      g.survival.visualCombo = 1;
      g.survival.points = 123456;
      g.score = 123456;
      g.survival.magnet = 10;
      g.survival.announce('MAX COMBO  +300');
      g.coins.addAll([
        BrassCoin(60, g.ballY - 55),
        BrassCoin(300, g.ballY - 100),
      ]);
      g.survival.items.addAll([
        InfiniteItem(InfiniteItemKind.shield, 85, g.ballY - 120),
        InfiniteItem(InfiniteItemKind.combo, 285, g.ballY - 150),
      ]);
      for (var frame = 0; frame < 3; frame++) {
        for (var i = 0; i < (frame == 0 ? 1 : 8); i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull);
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('artifacts').create(recursive: true);
          await File(
            'artifacts/infinite-updates-${width.toInt()}-$frame.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
