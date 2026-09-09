import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render laser maze picker, routes and finish', (tester) async {
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

    await capture('maze-home');
    await tester.ensureVisible(find.text('LASER MAZE'));
    await tester.tap(find.text('LASER MAZE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('maze-picker');
    await tester.ensureVisible(find.byKey(const ValueKey('maze-route-1')));
    await tester.tap(find.byKey(const ValueKey('maze-route-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    await capture('maze-route-1');
    // The finish sits above the route's last lane, not above the launch column.
    game.ballX = game.mazeRun.route!.finishX;
    game.left = game.right = 62;
    game.elapsed = 25;
    for (var side = 0; side < 2; side++) {
      game.grabPivot(side);
      game.dragPivot(side, -25);
    }
    await tester.pump(const Duration(milliseconds: 20));
    expect(game.won, true);
    await capture('maze-finish');
    await tester.tap(find.text('NEXT ROUTE'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(game.level, 2);
    game.start(gameMode: GameMode.laserMaze, levelNumber: 10);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('maze-route-10');
    game.start(gameMode: GameMode.mazeEndless);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('maze-endless-start');
    // Lift along the generated centerline so the scrolled corridor is visible.
    final maze = game.mazeRun.corridor as EndlessMaze;
    final high = maze.centers.firstWhere((p) => p.y < 240);
    game.ballX = high.x;
    game.left = game.right = high.y + BalanceGame.ballRadius;
    game.maxHeight = LaserMazeCorridor.startY - high.y;
    await tester.pump(const Duration(milliseconds: 20));
    await capture('maze-endless-climb');
    game.start(gameMode: GameMode.laserMaze, levelNumber: 10);
    await tester.pump(const Duration(milliseconds: 20));
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('maze-small-phone');
    for (var side = 0; side < 2; side++) {
      game.grabPivot(side);
      game.dragPivot(side, -480);
    }
    await tester.pump(const Duration(milliseconds: 20));
    expect(game.mazeRun.hitLaser, true);
    await capture('maze-laser-contact');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
