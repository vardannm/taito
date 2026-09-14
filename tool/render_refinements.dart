import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render refined backgrounds, fire, equipment and control cards', (
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
        ..haptics = false
        ..wallet = 2400
        ..selectedBall = BallCosmetic.nebula
        ..selectedPlatform = PlatformStyle.solar;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: p),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('controls-cards-${width.toInt()}');
      await tester.ensureVisible(
        find.byKey(const ValueKey('analog-sensitivity')),
      );
      await tester.pump();
      await capture('controls-sensitivity-${width.toInt()}');
      Navigator.of(tester.element(find.text('Make yourself at home.'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('GEAR SHOP'));
      await tester.tap(find.text('GEAR SHOP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('gear-shop-${width.toInt()}');
      await tester.ensureVisible(find.text('Platforms'));
      await tester.tap(find.text('Platforms'));
      await tester.pump();
      await capture('platform-shop-${width.toInt()}');
      Navigator.of(tester.element(find.text('Platforms'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('INFINITE'));
      await tester.tap(find.text('INFINITE'));
      await tester.pump();
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      await tester.pump(const Duration(milliseconds: 16));
      await capture('infinite-sparse-${width.toInt()}');
      for (final combo in [3, 5]) {
        g.survival.combo = combo;
        g.survival.visualCombo = (combo - 1) / 4;
        g.survival.shield = 8;
        g.survival.points = 8200;
        g.survival.announce('COMBO x$combo · Gear x3.5');
        g.survival.items.add(InfiniteItem(InfiniteItemKind.combo, 120, 220));
        await tester.pump(const Duration(milliseconds: 16));
        await capture('combo-$combo-${width.toInt()}');
      }
      await tester.pump(const Duration(milliseconds: 250));
      await capture('combo-fire-later-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
