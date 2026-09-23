import '../test/support/mode_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render star locks and optimized high combo effects', (
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

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      final profile = PlayerProfile()
        ..sound = false
        ..music = false
        ..haptics = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await tester.pump();
      await selectWorld(tester, 1);
      await capture('board-level-chooser-${width.toInt()}');
      await selectWorld(tester, 0);
      for (final stars in [0, 2]) {
        if (stars == 2)
          profile.levelRecords['twoFinger:1'] = const LevelRecord(starMask: 3);
        await openClassicLevels(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await capture('classic-stars-$stars-${width.toInt()}');
        Navigator.of(tester.element(find.byType(LevelPicker))).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.beginInput();
      game.maxHeight = 4500;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      for (final combo in [5, 8, 9, 10]) {
        game.survival.combo = combo;
        game.survival.visualCombo = (combo - 1) / 9;
        game.clock = 2;
        await tester.pump(const Duration(milliseconds: 16));
        await capture('optimized-combo-$combo-${width.toInt()}');
      }
      game.lives = 2;
      game.specialHazards
        ..clear()
        ..add(
          SpecialHazard(HazardKind.laser, x: 210, y: 90, warningSeconds: 0)
            ..step(.01, 0),
        );
      await tester.pump(const Duration(milliseconds: 30));
      await capture('laser-full-height-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      profile.wallet = 10000;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            home: Scaffold(body: BallShop(profile: profile)),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-plasma')).hitTestable(),
        250,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await capture('premium-balls-${width.toInt()}');
      // Return to the category tabs without changing any saved equipment.
      await tester.scrollUntilVisible(
        find.text('Platforms').hitTestable(),
        -300,
      );
      await tester.tap(find.text('Platforms'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-platform-celestial')).hitTestable(),
        250,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await capture('premium-platforms-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
