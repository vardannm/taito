import '../test/support/mode_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze_widgets.dart';
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

    await openMazeRoutes(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('maze-picker');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maze-route-20')).hitTestable(),
      200,
      scrollable: find.descendant(
        of: find.byType(LaserMazePicker),
        matching: find.byType(Scrollable),
      ),
    );
    await capture('maze-expert-picker');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maze-route-1')).hitTestable(),
      -160,
      scrollable: find.descendant(
        of: find.byType(LaserMazePicker),
        matching: find.byType(Scrollable),
      ),
    );
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
    for (final number in [2, 3, 4, 5, 6, 8]) {
      game.start(gameMode: GameMode.laserMaze, levelNumber: number);
      await tester.pump(const Duration(milliseconds: 20));
      await capture('maze-structure-$number');
    }
    for (final number in [11, 20]) {
      game.start(gameMode: GameMode.laserMaze, levelNumber: number);
      await tester.pump(const Duration(milliseconds: 20));
      await capture('maze-expert-$number-start');
      final route = game.mazeRun.route!;
      final leg = route.legs.firstWhere(
        (l) => l.primary && l.b.y < l.a.y && l.a.y < -500,
      );
      game.ballX = leg.a.x;
      game.left = game.right = (leg.a.y + leg.b.y) / 2 + BalanceGame.ballRadius;
      game.cameraOffset = 360 - game.ballY;
      for (var frame = 0; frame < 16; frame++) {
        for (var side = 0; side < 2; side++) {
          game.grabPivot(side);
          game.dragPivot(side, -1.5);
        }
        game.step(1 / 120);
      }
      for (var side = 0; side < 2; side++) game.dragPivot(side, -1.5);
      await tester.pump(const Duration(milliseconds: 8));
      expect(game.finished, false);
      await capture('maze-expert-$number-climb');
      game.clearInput();
      game.ballX = route.finishX;
      game.left = game.right = route.finishLineY + 42;
      game.cameraOffset = 360 - game.ballY;
      await tester.pump(const Duration(milliseconds: 20));
      await capture('maze-expert-$number-summit');
    }
    game.start(gameMode: GameMode.infinite);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('infinite-random-coins');
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
    await tester.tap(find.text('ALL ROUTES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('maze-route-20')).hitTestable(),
      200,
      scrollable: find.descendant(
        of: find.byType(LaserMazePicker),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('maze-route-20')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.level, 20);
    expect(game.finished, false);
    expect(find.byType(LaserMazeResult), findsNothing);
    await capture('maze-expert-small-phone');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
