import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render magnet pickup, field and shop on phones', (tester) async {
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
      final height = width == 390 ? 844.0 : 568.0;
      tester.view.physicalSize = Size(width, height);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false
        ..wallet = 248;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: p),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Modes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('GEAR SHOP'));
      await tester.tap(find.text('GEAR SHOP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-plasma')),
        350,
        scrollable: find
            .descendant(
              of: find.byType(BallShop),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      await capture('magnet-shop-${width.toInt()}');
      Navigator.of(tester.element(find.byType(BallShop))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      g.survival.combo = 5;
      g.survival.visualCombo = 1;
      g.survival.shield = 7.4;
      g.survival.magnet = 9.2;
      g.beginInput();
      g.survival.announce('MAGNET - Nearby rewards collected');
      g.survival.points = 4280;
      g.maxHeight = 5100;
      g.cosmetic = BallCosmetic.plasma;
      g.survival.items.addAll([
        InfiniteItem(InfiniteItemKind.magnet, 120, g.ballY - 270),
        InfiniteItem(InfiniteItemKind.shield, 255, g.ballY - 300),
        InfiniteItem(InfiniteItemKind.heart, 200, g.ballY - 250),
      ]);
      await tester.pump(const Duration(milliseconds: 16));
      await capture('infinite-magnet-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
