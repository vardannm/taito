import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/onboarding.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render live onboarding on small and tall phones', (
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
    Future<void> frames() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final picture =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await tester.runAsync(() async {
        final data = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/onboarding').create(recursive: true);
        await File(
          'artifacts/onboarding/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
      picture.dispose();
    }

    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
      for (final step in [
        TutorialStep.controls,
        TutorialStep.heartsHoles,
        TutorialStep.shield,
        TutorialStep.shop,
        TutorialStep.levels,
        TutorialStep.classicPlay,
        TutorialStep.dailyChallenge,
      ]) {
        final p = PlayerProfile()
          ..sound = false
          ..music = false
          ..haptics = false
          ..tutorial = TutorialProgress(step: step)
          ..wallet = 1;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ArcadeApp(key: UniqueKey(), profile: p),
          ),
        );
        await frames();
        await capture('${step.name}-${width.toInt()}');
        if (step == TutorialStep.shop) {
          await tester.tap(find.byKey(const ValueKey('board-shop')));
          await frames();
          await capture('shopBall-${width.toInt()}');
          await tester.tap(find.byKey(const ValueKey('buy-steel')));
          await frames();
          await capture('shopPlatform-${width.toInt()}');
        }
        if (step == TutorialStep.levels) {
          await tester.tap(find.byTooltip('Classic levels'));
          await frames();
          await capture('levelPicker-${width.toInt()}');
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
