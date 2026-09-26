import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/laser_maze.dart';

void verifyRoad(LaserMazeCorridor road) {
  for (final leg in road.legs) {
    expect(leg.halfWidth, greaterThanOrEqualTo(13));
    expect(
      road.firstContact(leg.a.x, leg.a.y, leg.b.x, leg.b.y, 7),
      isNull,
      reason: '${leg.a.x},${leg.a.y} -> ${leg.b.x},${leg.b.y}',
    );
  }
  final wallKeys = <String>{};
  for (final wall in road.walls) {
    expect(
      wallKeys.add('${wall.a.x}/${wall.a.y}/${wall.b.x}/${wall.b.y}'),
      true,
    );
    expect(LaserMazeCorridor.pointDistance(wall.a, wall.b), greaterThan(.001));
    final x = (wall.a.x + wall.b.x) / 2, y = (wall.a.y + wall.b.y) / 2;
    final insideA = road.contains(
      x + (wall.vertical ? .02 : 0),
      y + (wall.vertical ? 0 : .02),
    );
    final insideB = road.contains(
      x - (wall.vertical ? .02 : 0),
      y - (wall.vertical ? 0 : .02),
    );
    expect(
      insideA != insideB,
      true,
      reason: 'Wall must separate road from land',
    );
  }
}

void main() {
  test('all ten redesigned routes and every shortcut fit the ball', () {
    var forks = 0;
    for (var level = 1; level <= 10; level++) {
      final route = LaserMazeRoute(level);
      verifyRoad(route);
      for (final branch in route.branches) {
        forks++;
        expect(branch.halfWidth, lessThan(route.halfWidth - 6));
        expect(branch.length, lessThan((branch.toArc - branch.fromArc) * .8));
        final from = branch.points.first, to = branch.points.last;
        expect(
          route.progressAt(from.x, from.y),
          closeTo(
            (branch.fromArc - route.startArc) /
                (route.finishArc - route.startArc),
            .00001,
          ),
        );
        expect(
          route.progressAt(to.x, to.y),
          closeTo(
            (branch.toArc - route.startArc) /
                (route.finishArc - route.startArc),
            .00001,
          ),
        );
      }
    }
    expect(forks, greaterThanOrEqualTo(7));
  });

  test('an upward-only ball cannot complete the required return routes', () {
    for (final level in [1, 2, 4, 7, 9]) {
      final route = LaserMazeRoute(level);
      final queue = <(int, int)>[(45, 129)], seen = <(int, int)>{(45, 129)};
      var reached = false;
      for (var head = 0; head < queue.length; head++) {
        final cell = queue[head];
        if (cell.$2 * 4 <= 44) {
          reached = true;
          break;
        }
        for (final offset in [(-1, 0), (1, 0), (0, -1)]) {
          final next = (cell.$1 + offset.$1, cell.$2 + offset.$2);
          if (next.$1 < 8 || next.$1 > 82 || next.$2 < 10 || !seen.add(next))
            continue;
          if (route.firstContact(
                cell.$1 * 4.0,
                cell.$2 * 4.0,
                next.$1 * 4.0,
                next.$2 * 4.0,
                7,
              ) ==
              null)
            queue.add(next);
        }
      }
      expect(
        reached,
        false,
        reason: 'Route $level must require downward travel',
      );
    }
  });

  test(
    'procedural modules vary, reconnect safely and stay bounded over long runs',
    () {
      final signatures = <String>{}, structures = <MazeStructure>{};
      var modules = 0, branches = 0, returns = 0;
      for (var seed = 0; seed < 24; seed++) {
        final road = EndlessMaze(seed: seed);
        final seen = <int>{};
        MazeStructure? previous;
        final recent = <String>[];
        for (var section = 0; section < 25; section++) {
          final ballY = 360 - section * 400.0;
          road.extendTo(ballY - 620, behindY: ballY + 800);
          verifyRoad(road);
          expect(road.rects.length, lessThan(180));
          for (final chunk in road.chunks) {
            if (!seen.add(chunk.id)) continue;
            expect(chunk.structure, isNot(previous));
            expect(recent.contains(chunk.signature), false);
            previous = chunk.structure;
            recent.add(chunk.signature);
            if (recent.length > 8) recent.removeAt(0);
            signatures.add(chunk.signature);
            structures.add(chunk.structure);
            modules++;
            branches += road.branches.where((b) => b.chunk == chunk.id).length;
            returns += road.legs
                .where((l) => l.chunk == chunk.id && l.primary && l.b.y > l.a.y)
                .length;
          }
        }
      }
      expect(modules, greaterThan(400));
      expect(signatures.length, greaterThan(modules * .85));
      expect(structures.length, MazeStructure.values.length);
      expect(branches, greaterThan(200));
      expect(returns, greaterThanOrEqualTo(modules));
    },
  );

  test(
    'endless camera follows a downward return without banking height twice',
    () {
      final g = BalanceGame(seed: 4)..start(gameMode: GameMode.mazeEndless);
      final leg = g.mazeRun.corridor.legs.firstWhere(
        (l) => l.primary && l.b.y > l.a.y && l.a.y < 280,
      );
      g.ballX = leg.a.x;
      g.left = g.right = leg.a.y + BalanceGame.ballRadius;
      g.cameraOffset = math.max(0, 360 - g.ballY);
      g.step(1 / 120);
      final height = g.maxHeight, score = g.score, camera = g.cameraOffset;
      for (final side in [0, 1]) {
        g.grabPivot(side);
        g.dragPivot(side, leg.b.y - leg.a.y);
        g.releasePivot(side);
      }
      g.step(1 / 120);
      expect(g.finished, false);
      expect(g.ballY, closeTo(leg.b.y, .01));
      expect(g.cameraOffset, lessThan(camera));
      expect(g.maxHeight, height);
      expect(g.score, score);
      expect(g.screenY(g.ballY), lessThanOrEqualTo(440));
      expect(
        g.mazeRun.corridor.firstContact(leg.b.x, leg.b.y, leg.a.x, leg.a.y, 7),
        isNull,
      );
    },
  );
}
