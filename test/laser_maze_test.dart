import 'support/mode_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:balance_arcade/laser_maze_widgets.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Places the ball in the final column just below the finish line and lifts it
/// across. The finish is no longer above the launch column, so the helper has
/// to move to the route's last lane first.
void finishMaze(BalanceGame game) {
  final route = game.mazeRun.route!;
  game.ballX = route.finishX;
  game.left = game.right = route.finishLineY + 18;
  if (route.tall) game.cameraOffset = 360 - game.ballY;
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

/// Walks the centerline of a corridor with a ball-sized swept circle. Endless
/// corridors grow and prune while walking, so the waypoint is tracked by value.
({bool contacted, double climbed, int legs}) walkCenterline(
  LaserMazeRun run, {
  int maxLegs = 400,
}) {
  final corridor = run.corridor;
  var x = 180.0, y = LaserMazeCorridor.startY, legs = 0;
  var target = corridor.centers[1];
  while (legs < maxLegs) {
    var index = corridor.centers.indexWhere(
      (p) => p.x == target.x && p.y == target.y,
    );
    if (index < 1) index = 1;
    final destination = corridor.centers[index];
    final steps =
        ((destination.x - x).abs() + (destination.y - y).abs()) ~/ 2 + 1;
    final fromX = x, fromY = y;
    for (var i = 1; i <= steps; i++) {
      final nextX = fromX + (destination.x - fromX) * i / steps;
      final nextY = fromY + (destination.y - fromY) * i / steps;
      run.step(x, y, nextX, nextY, BalanceGame.ballRadius);
      if (run.hitLaser) {
        return (contacted: true, climbed: 548 - nextY, legs: legs);
      }
      x = nextX;
      y = nextY;
      if (run.won) return (contacted: false, climbed: 548 - y, legs: legs);
    }
    legs++;
    index = corridor.centers.indexWhere(
      (p) => p.x == destination.x && p.y == destination.y,
    );
    if (index < 0 || index + 1 >= corridor.centers.length) break;
    target = corridor.centers[index + 1];
  }
  return (contacted: false, climbed: 548 - y, legs: legs);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('twenty routes narrow progressively and fit their map bounds', () {
    final shapes = <String>{};
    var previousWidth = double.infinity;
    for (var i = 1; i <= LaserMazeRoute.count; i++) {
      final route = LaserMazeRoute(i);
      expect(route.halfWidth, lessThan(previousWidth));
      previousWidth = route.halfWidth;
      shapes.add(route.centers.map((p) => '${p.x}/${p.y}').join(','));
      for (final wall in route.walls) {
        for (final point in [wall.a, wall.b]) {
          expect(point.x, inInclusiveRange(30, 330));
          expect(point.y, inInclusiveRange(route.routeTop, 548));
        }
      }
      expect(route.contains(180, LaserMazeCorridor.startY), true);
      expect(route.firstContact(180, 519, 180, 519, 7), isNull);
      expect(route.contains(route.finishX, route.finishLineY), true);
    }
    expect(shapes.length, LaserMazeRoute.count);
    expect(LaserMazeRoute(0).number, 1);
    expect(LaserMazeRoute(99).number, 20);
  });

  test('every route includes a real downward return and orthogonal legs', () {
    for (var level = 1; level <= LaserMazeRoute.count; level++) {
      final route = LaserMazeRoute(level);
      expect(route.legs.where((l) => l.primary && l.b.y > l.a.y), isNotEmpty);
      for (final leg in route.legs) {
        expect(leg.a.x == leg.b.x || leg.a.y == leg.b.y, true);
      }
    }
  });
  test('a straight climb up the launch column hits a wall on every route', () {
    for (var level = 1; level <= LaserMazeRoute.count; level++) {
      final run = LaserMazeRun(level);
      run.step(180, LaserMazeCorridor.startY, 180, 44, 7);
      expect(run.hitLaser, true, reason: 'Route $level');
      expect(run.won, false, reason: 'Route $level');
    }
  });

  test('the complete centerline of every route clears the ball and wins', () {
    for (var level = 1; level <= LaserMazeRoute.count; level++) {
      final run = LaserMazeRun(level);
      final walk = walkCenterline(run);
      expect(walk.contacted, false, reason: 'Route $level');
      expect(run.won, true, reason: 'Route $level');
      expect(run.progress, 1);
      expect(run.contactY, closeTo(run.route!.finishLineY, .001));
    }
  });

  test('progress starts at zero and follows the whole winding centerline', () {
    final route = LaserMazeRoute(10);
    expect(route.progressAt(180, LaserMazeCorridor.startY), closeTo(0, .001));
    expect(
      route.progressAt(route.finishX, LaserMazeCorridor.finishY),
      closeTo(1, .001),
    );
    // Halfway along the road is not halfway up the board: the sideways legs
    // count towards progress as well.
    final middle = route.centers[route.centers.length ~/ 2];
    expect(route.progressAt(middle.x, middle.y), inExclusiveRange(.3, .7));
  });

  test('fast shortcuts hit a laser even when both endpoints are inside', () {
    final run = LaserMazeRun(10);
    expect(run.corridor.contains(180, 519), true);
    run.step(180, 519, run.route!.finishX, 40, 7);
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
    final corner = route.walls.first.a;
    expect(route.firstContact(corner.x, corner.y, corner.x, corner.y, 7), 0);
    final t = route.firstContact(180, 510, 300, 510, 7);
    expect(t, isNotNull);
    expect(t!, closeTo((route.halfWidth - 9) / 120, .001));
  });

  test('the finish line only counts inside the final column', () {
    final run = LaserMazeRun(10);
    final finishX = run.route!.finishX;
    run.step(finishX, 64, finishX, 20, 7);
    expect(run.won, true);
    expect(run.hitLaser, false);
    expect(run.contactY, 44);
    final other = LaserMazeRun(10);
    // Crossing the finish height in the wrong lane is a wall, not a win.
    other.step(68, 120, 68, 20, 7);
    expect(other.won, false);
    expect(other.hitLaser, true);
  });

  test(
    'progress tracks the peak and cannot be farmed by going down and up',
    () {
      final run = LaserMazeRun(1);
      run.step(180, 519, 180, 480, 7);
      final peak = run.progress;
      expect(peak, greaterThan(0));
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
      expect(g.ballY, LaserMazeCorridor.startY);
      g.step(.1);
      expect(g.controlMode, control);
      expect(
        g.ballY,
        closeTo(control == ControlMode.oneFinger ? 517.6 : 519, .001),
      );
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
    'maze respects the selected controls across replay and mode changes',
    () {
      for (final control in ControlMode.values) {
        final g = BalanceGame()..setControlMode(control);
        for (final mode in [GameMode.laserMaze]) {
          g.start(gameMode: mode);
          expect(g.controlMode, control);
          expect(g.preferredControlMode, control);
          g.start(gameMode: mode);
          expect(g.controlMode, control);
          g.home();
          expect(g.controlMode, control);
          g.start(gameMode: GameMode.infinite);
          expect(g.controlMode, control);
        }
      }
    },
  );
  test('a fast two-pivot swipe cannot skip the labyrinth', () {
    for (final mode in [GameMode.laserMaze]) {
      final g = BalanceGame()..start(gameMode: mode, levelNumber: 10);
      for (var side = 0; side < 2; side++) {
        g.grabPivot(side);
        g.dragPivot(side, -480);
        g.releasePivot(side);
      }
      g.step(1 / 120);
      expect(g.finished, true, reason: '$mode');
      expect(g.won, false);
      expect(g.lives, 0);
      expect(g.event, GameEvent.miss);
      expect(g.mazeRun.hitLaser, true);
      expect(g.ballX, g.mazeRun.contactX);
      expect(g.ballY, closeTo(g.mazeRun.contactY, .001));
      expect(g.pivotTargets, [null, null]);
    }
  });

  test(
    'maze records persist per route and control',
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
      expect(p.mazeBestTime(7, ControlMode.twoFinger), first);
      expect(p.mazeBestTime(7, ControlMode.analog), lessThan(first));
      expect(p.mazeRuns, 3);
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
      expect(restored.mazeBestTime(7), p.mazeBestTime(7));
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

        await openMazeRoutes(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(LaserMazePicker), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('maze-route-1')).hitTestable(),
          160,
          scrollable: find.descendant(
            of: find.byType(LaserMazePicker),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('maze-route-1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
        expect(g.maze, true);
        expect(find.text('ROUTE 1'), findsOneWidget);
        expect(g.controlMode, ControlMode.analog);
        expect(p.controlMode, ControlMode.analog);
        expect(find.byKey(const ValueKey('analog-left')), findsOneWidget);
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
