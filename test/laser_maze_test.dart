import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:balance_arcade/laser_maze_widgets.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void finishMaze(BalanceGame game) {
  game.ballX = 180;
  game.left = game.right = 60;
  game.velocity = 0;
  if (game.oneFinger) {
    game.setControlPosition(0);
    for (var i = 0; i < 20 && !game.finished; i++) game.step(.1);
  } else {
    for (var side = 0; side < 2; side++) {
      game.grabPivot(side);
      game.dragPivot(side, -25);
    }
    game.step(1 / 120);
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('ten distinct routes narrow progressively and fit within the board', () {
    final shapes = <String>{};
    var previousWidth = double.infinity;
    for (var i = 1; i <= LaserMazeRoute.count; i++) {
      final route = LaserMazeRoute(i);
      expect(route.halfWidth, lessThan(previousWidth));
      previousWidth = route.halfWidth;
      shapes.add(route.centers.map((p) => '${p.x}/${p.y}').join(','));
      for (final point in [...route.leftWall, ...route.rightWall]) {
        expect(point.x, inInclusiveRange(30, 330));
        expect(point.y, inInclusiveRange(24, 548));
      }
      expect(route.contains(180, LaserMazeRoute.startY), true);
      expect(route.firstContact(180, 519, 180, 519, 7), isNull);
      expect(route.centerAt(LaserMazeRoute.finishY), 180);
    }
    expect(shapes.length, LaserMazeRoute.count);
    expect(LaserMazeRoute(0).number, 1);
    expect(LaserMazeRoute(99).number, 10);
  });
  test(
    'the complete centerline of every route clears the ball and reaches the finish',
    () {
      for (var level = 1; level <= LaserMazeRoute.count; level++) {
        final run = LaserMazeRun(level);
        var x = 180.0, y = LaserMazeRoute.startY;
        for (final destination in run.route.centers.where((p) => p.y < y)) {
          final steps = ((y - destination.y) / 2).ceil();
          final startX = x, startY = y;
          for (var i = 1; i <= steps && !run.ended; i++) {
            final nextX = startX + (destination.x - startX) * i / steps;
            final nextY = startY + (destination.y - startY) * i / steps;
            run.step(x, y, nextX, nextY, 7);
            expect(
              run.hitLaser,
              false,
              reason: 'Route $level at $nextX/$nextY',
            );
            x = nextX;
            y = nextY;
          }
          if (run.ended) break;
        }
        expect(run.won, true, reason: 'Route $level');
        expect(run.progress, 1);
        expect(run.contactY, closeTo(LaserMazeRoute.finishY, .001));
      }
    },
  );
  test('fast shortcuts hit a laser even when both endpoints are inside', () {
    final run = LaserMazeRun(10);
    expect(run.route.contains(180, 519), true);
    expect(run.route.contains(180, 40), true);
    run.step(180, 519, 180, 40, 7);
    expect(run.hitLaser, true);
    expect(run.won, false);
    expect(run.progress, lessThan(1));
    expect(run.contactY, greaterThan(44));
  });
  test('wall contact includes ball radius and rounded laser corners', () {
    final route = LaserMazeRoute(10);
    final x = 180 + route.halfWidth - 9;
    expect(route.firstContact(x - .1, 510, x - .1, 500, 7), isNull);
    expect(route.firstContact(x + .1, 510, x + .1, 500, 7), 0);
    final corner = route.leftWall[3];
    expect(route.firstContact(corner.x, corner.y, corner.x, corner.y, 7), 0);
    final t = route.firstContact(180, 510, 300, 510, 7);
    expect(t, isNotNull);
    expect(t!, closeTo((route.halfWidth - 9) / 120, .001));
  });
  test(
    'crossing the finish first wins even if the rest of a swipe crosses a wall',
    () {
      final run = LaserMazeRun(10);
      run.step(180, 64, 240, 0, 7);
      expect(run.won, true);
      expect(run.hitLaser, false);
      expect(run.contactY, 44);
      run.step(240, 0, 0, 500, 7);
      expect(run.won, true);
    },
  );
  test(
    'progress tracks peak height and cannot be farmed by going down and up',
    () {
      final run = LaserMazeRun(1);
      run.step(180, 519, 180, 480, 7);
      final peak = run.progress;
      run.step(180, 480, 180, 510, 7);
      expect(run.progress, peak);
      run.step(180, 510, 180, 490, 7);
      expect(run.progress, peak);
    },
  );
  for (final control in ControlMode.values) {
    test('maze launch, pause, finish and replay work with $control', () {
      final g = BalanceGame()
        ..setControlMode(control)
        ..start(gameMode: GameMode.laserMaze, levelNumber: 7);
      expect(g.maze, true);
      expect(g.level, 7);
      expect(g.board, isEmpty);
      expect(g.spiders, isEmpty);
      expect(g.coins, isEmpty);
      expect(g.specialHazards, isEmpty);
      expect(g.lives, 1);
      expect(g.ballY, LaserMazeRoute.startY);
      g.step(.1);
      if (control == ControlMode.oneFinger) expect(g.ballY, lessThan(519));
      g.setPaused(true);
      final before = (g.ballX, g.ballY, g.elapsed, g.mazeRun.progress);
      g.step(.1);
      expect((g.ballX, g.ballY, g.elapsed, g.mazeRun.progress), before);
      g.setPaused(false);
      finishMaze(g);
      expect(g.won, true);
      expect(g.finished, true);
      expect(g.score, 100);
      expect(g.event, GameEvent.complete);
      expect(g.earnedStarMask, 0);
      g.start(gameMode: GameMode.laserMaze, levelNumber: 7);
      expect(g.mazeRun.ended, false);
      expect(g.mazeRun.progress, 0);
      expect(g.score, 0);
      expect(g.canControl, true);
    });
  }
  test(
    'a fast two-pivot swipe cannot skip the labyrinth and claim a finish',
    () {
      final g = BalanceGame()
        ..start(gameMode: GameMode.laserMaze, levelNumber: 10);
      for (var side = 0; side < 2; side++) {
        g.grabPivot(side);
        g.dragPivot(side, -480);
        g.releasePivot(side);
      }
      g.step(1 / 120);
      expect(g.finished, true);
      expect(g.won, false);
      expect(g.lives, 0);
      expect(g.event, GameEvent.miss);
      expect(g.mazeRun.hitLaser, true);
      expect(g.ballX, g.mazeRun.contactX);
      expect(g.ballY, closeTo(g.mazeRun.contactY, .001));
      expect(g.ballY, greaterThan(LaserMazeRoute.finishY));
      expect(g.pivotTargets, [null, null]);
    },
  );
  test(
    'maze records persist per route and control without changing Classic or merge',
    () async {
      final p = PlayerProfile()
        ..classicLevel = 31
        ..mazeLevel = 7;
      final g = BalanceGame()
        ..start(gameMode: GameMode.laserMaze, levelNumber: 7);
      g.elapsed = 12;
      finishMaze(g);
      expect(p.recordResult(g), true);
      final first = p.mazeBestTime(7)!;
      expect(p.recordResult(g), false);
      expect(p.mazeRuns, 1);
      g.start(gameMode: GameMode.laserMaze, levelNumber: 7);
      g.elapsed = 18;
      finishMaze(g);
      expect(p.recordResult(g), false);
      expect(p.mazeBestTime(7), first);
      g.setControlMode(ControlMode.analog);
      g.start(gameMode: GameMode.laserMaze, levelNumber: 7);
      g.elapsed = 8;
      finishMaze(g);
      expect(p.recordResult(g), true);
      expect(p.mazeBestTime(7, ControlMode.analog), lessThan(first));
      expect(p.best, 0);
      expect(p.runs, 0);
      expect(p.mergeRuns, 0);
      expect(p.totalStars, 0);
      await p.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.classicLevel, 31);
      expect(restored.mazeLevel, 7);
      expect(restored.mazeRuns, 3);
      expect(restored.mazeBestTime(7), first);
      expect(
        restored.mazeBestTime(7, ControlMode.analog),
        p.mazeBestTime(7, ControlMode.analog),
      );
    },
  );
  test('lost routes count an attempt without earning a completion time', () {
    final p = PlayerProfile();
    final g = BalanceGame()..start(gameMode: GameMode.laserMaze);
    g.ballX = 300;
    g.step(1 / 120);
    p.recordResult(g);
    expect(p.mazeRuns, 1);
    expect(p.mazeBestTime(1), isNull);
  });
  for (final layout in [
    (const Size(320, 568), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    testWidgets(
      'maze picker, controls, retry and next route fit ${layout.$1} at ${layout.$2}',
      (tester) async {
        tester.view.physicalSize = layout.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final p = PlayerProfile()
          ..tutorialSeen = true
          ..sound = false
          ..haptics = false
          ..controlMode = ControlMode.analog;
        await tester.pumpWidget(ArcadeApp(profile: p));
        await tester.ensureVisible(find.text('LASER MAZE'));
        await tester.tap(find.text('LASER MAZE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(LaserMazePicker), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('maze-route-1')));
        await tester.tap(find.byKey(const ValueKey('maze-route-1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
        expect(g.maze, true);
        expect(find.text('LASER MAZE / ROUTE 1'), findsOneWidget);
        final joystick = tester.getRect(
          find.byKey(const ValueKey('analog-left')),
        );
        expect(joystick.bottom, lessThanOrEqualTo(layout.$1.height - 24));
        finishMaze(g);
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('Finish reached.'), findsOneWidget);
        await tester.ensureVisible(find.text('NEXT ROUTE'));
        await tester.tap(find.text('NEXT ROUTE'));
        await tester.pump(const Duration(milliseconds: 30));
        expect(g.level, 2);
        expect(p.mazeLevel, 2);
        expect(p.classicLevel, 1);
        g.ballX = 300;
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('Laser contact.'), findsOneWidget);
        await tester.ensureVisible(find.text('RETRY ROUTE'));
        await tester.tap(find.text('RETRY ROUTE'));
        await tester.pump(const Duration(milliseconds: 30));
        expect(g.level, 2);
        expect(g.finished, false);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
