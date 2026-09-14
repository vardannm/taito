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
  testWidgets('render 2048 snake gameplay, gates and results', (tester) async {
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
    game.mergeRun.segments
      ..clear()
      ..addAll([32, 16, 8, 4, 2]);
    game.mergeRun.highest = 32;
    game.left = 480;
    game.right = 480;
    game.mergeRun.orbs
      ..clear()
      ..addAll([
        NumberOrb(80, 110, 2),
        NumberOrb(220, 85, 4),
        NumberOrb(140, 205, 8),
        NumberOrb(280, 270, 16),
        NumberOrb(70, 315, 32),
        NumberOrb(205, 390, 1024),
        NumberOrb(110, 435, 2048),
        NumberOrb(285, 150, 128),
        NumberOrb(50, 215, 1048576),
      ]);
    game.mergeRun.gates.add(MergeGate(64, y: 240));
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-centered-phone');
    game.mergeRun.orbs.add(NumberOrb(game.ballX, game.ballY, 2));
    await tester.pump(const Duration(milliseconds: 20));
    expect(game.mergeRun.segments, [64]);
    await capture('merge-centered-64');

    game.start(gameMode: GameMode.merge2048);
    game.mergeRun.gates.clear();
    game.mergeRun.segments
      ..clear()
      ..add(1024);
    game.mergeRun.highest = 1024;
    game.mergeRun.orbs
      ..clear()
      ..add(NumberOrb(game.ballX, game.ballY, 1024));
    await tester.pump(const Duration(milliseconds: 20));
    expect(game.finished, false);
    await capture('merge-2k-running');
    game.mergeRun.segments
      ..clear()
      ..addAll([2097152, 1048576, 2048, 1024, 512]);
    game.mergeRun.highest = 2097152;
    game.mergeRun.flash = 0;
    game.mergeRun.orbs.addAll([
      NumberOrb(95, 130, 1024),
      NumberOrb(240, 230, 2048),
      NumberOrb(150, 315, 1048576),
      NumberOrb(260, 400, 2097152),
    ]);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-millions');

    game.mergeRun.orbs.clear();
    game.mergeRun.segments
      ..clear()
      ..addAll(
        List.generate(
          MergeRun.maxSegments,
          (i) => 1 << (MergeRun.maxSegments - i),
        ),
      );
    game.mergeRun.highest = 4096;
    game.left = 450;
    game.right = 490;
    game.ballX = 180;
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-centered-full');
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-centered-small');
    game.mergeRun.collect(8192);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-large-number-loss');

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump(const Duration(milliseconds: 20));
    game.mergeRun.orbs.clear();
    game.mergeRun.gates.add(MergeGate(4096, y: game.ballY));
    await tester.pump(const Duration(milliseconds: 20));
    await capture('merge-gate-loss');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
