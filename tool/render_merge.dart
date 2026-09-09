import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/merge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render 2048 gameplay and win screens', (tester) async {
    for (final family in ['sans-serif', 'monospace', 'Roboto']) {
      final loader = FontLoader(family);
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false;
    profile.controlMode = ControlMode.analog;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ArcadeApp(profile: profile),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      await tester.runAsync(() => saveImage(image, 'artifacts/$name.png'));
    }

    await capture('merge-home');
    await tester.ensureVisible(find.text('2048  /  MERGE'));
    await tester.tap(find.text('2048  /  MERGE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('merge-guide');
    await tester.tap(find.text('PLAY 2048'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    game.mergeRun.stack
      ..clear()
      ..addAll([32, 16, 8]);
    game.mergeRun.orbs
      ..clear()
      ..addAll([
        NumberOrb(80, 110, 2),
        NumberOrb(220, 85, 4),
        NumberOrb(140, 205, 8),
        NumberOrb(280, 270, 16),
        NumberOrb(70, 315, 32),
        NumberOrb(205, 390, 8),
        NumberOrb(110, 435, 64),
        NumberOrb(285, 150, 128),
      ]);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-phone');
    game.mergeRun.stack
      ..clear()
      ..addAll([64, 32, 16, 8, 4, 2]);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-full-stack');
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-small-phone');
    game.mergeRun.stack
      ..clear()
      ..add(1024);
    game.mergeRun.orbs
      ..clear()
      ..add(NumberOrb(game.ballX, game.ballY, 1024));
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-win-small');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
