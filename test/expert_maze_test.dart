import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'laser_maze_test.dart' show finishMaze;

void main() {
  test('expert maps are tall, narrow, connected and include safe branches', () {
    for (var number = 11; number <= 20; number++) {
      final route = LaserMazeRoute(number);
      expect(route.mapHeight, greaterThan(1400));
      expect(route.finishLineY, lessThan(-800));
      expect(route.halfWidth, lessThan(20));
      expect(route.branches, isNotEmpty);
      for (final leg in route.legs) {
        expect(leg.halfWidth, greaterThan(11));
        expect(
          route.firstContact(leg.a.x, leg.a.y, leg.b.x, leg.b.y, 7),
          isNull,
          reason:
              'Route $number: ${leg.a.x},${leg.a.y} -> ${leg.b.x},${leg.b.y}',
        );
      }
      final copy = LaserMazeRoute(number);
      expect(
        copy.centers.map((p) => (p.x, p.y)),
        route.centers.map((p) => (p.x, p.y)),
      );
    }
  });

  test(
    'expert camera follows both directions and only the real finish wins',
    () {
      final game = BalanceGame()
        ..start(gameMode: GameMode.laserMaze, levelNumber: 20);
      final route = game.mazeRun.route!;
      expect(game.coins, isEmpty);
      expect(game.spiders, isEmpty);
      final down = route.legs.firstWhere(
        (l) => l.primary && l.b.y > l.a.y && l.a.y < -100,
      );
      game.ballX = down.a.x;
      game.left = game.right = down.a.y + BalanceGame.ballRadius;
      game.cameraOffset = 360 - game.ballY;
      game.step(1 / 120);
      final camera = game.cameraOffset;
      for (var side = 0; side < 2; side++) {
        game.grabPivot(side);
        game.dragPivot(side, down.b.y - down.a.y);
        game.releasePivot(side);
      }
      game.step(1 / 120);
      expect(game.finished, false);
      expect(game.cameraOffset, lessThan(camera));
      expect(game.ballY, closeTo(down.b.y, .001));
      expect(game.screenY(game.ballY), lessThanOrEqualTo(440));
      finishMaze(game);
      expect(game.won, true);
      expect(game.ballY, closeTo(route.finishLineY, .001));
      expect(game.score, 100);
      expect(game.screenY(game.ballY), inInclusiveRange(40, 440));
      expect(game.screenY(route.finishLineY), closeTo(44, .001));
      game.start(gameMode: GameMode.laserMaze, levelNumber: 1);
      expect(game.scrolling, false);
      expect(game.cameraOffset, 0);
    },
  );

  test(
    'expert completions and selected level survive profile reload',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final profile = PlayerProfile()..mazeLevel = 20;
      final game = BalanceGame()
        ..start(gameMode: GameMode.laserMaze, levelNumber: 20);
      game.elapsed = 120;
      finishMaze(game);
      expect(game.won, true);
      expect(profile.recordResult(game), true);
      await profile.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.mazeLevel, 20);
      expect(restored.mazeBestTime(20), profile.mazeBestTime(20));
    },
  );

  test('motion wake is bounded, fades, pauses and clears on restart', () {
    final game = BalanceGame()..start(gameMode: GameMode.practice);
    game.step(.1);
    expect(game.ballTrail, isEmpty);
    for (var i = 0; i < 50; i++) {
      for (var side = 0; side < 2; side++) {
        game.grabPivot(side);
        game.dragPivot(side, -.5);
      }
      game.step(1 / 120);
    }
    expect(game.ballTrail, isNotEmpty);
    expect(game.ballTrail.length, lessThanOrEqualTo(24));
    expect(game.motionSpeed, closeTo(60, .001));
    final heldY = game.ballY;
    game.step(1 / 120);
    expect(game.ballY, heldY);
    expect(
      game.motionSpeed,
      greaterThan(40),
      reason: 'The glow remains visible between input samples at 60 Hz',
    );
    game.setPaused(true);
    final samples = game.ballTrail.toList();
    game.step(.1);
    expect(game.ballTrail, samples);
    game.setPaused(false);
    for (var i = 0; i < 4; i++) game.step(.1);
    expect(game.ballTrail, isEmpty);
    expect(game.motionSpeed, 0);
    game.start();
    expect(game.ballTrail, isEmpty);
  });
}
