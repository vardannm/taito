import 'package:balance_arcade/capture_run.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import '../../tool/classic_level_routes.dart';

/// A small test driver that completes level 1 using accepted pivot commands.
/// It never edits ball position, target progression, health, or results.
class LevelRecordingDriver {
  int target = 0, index = 0;
  List<(double, double)> path = [];
  void move(BalanceGame g) {
    if (!g.canControl) return;
    if (g.target != target) {
      target = g.target;
      index = 0;
      final definition = ClassicLevels.definition(1);
      final route = routeToTarget(
        definition,
        definition.holes.singleWhere((h) => h.target == target),
      )!;
      path = [route.first];
      for (var k = 1; k < route.length - 1; k++) {
        final a = route[k - 1], b = route[k], c = route[k + 1];
        if ((b.$1 - a.$1) * (c.$2 - b.$2) != (b.$2 - a.$2) * (c.$1 - b.$1))
          path.add(b);
      }
      path.add(route.last);
    }
    {
      var goal = path[index];
      if (index < path.length - 1 &&
          (g.ballX - goal.$1).abs() < 3 &&
          (g.ballY - goal.$2).abs() < 3 &&
          g.velocity.abs() < 7)
        goal = path[++index];
      final slope = ((goal.$1 - g.ballX) * .009 - g.velocity * .045).clamp(
        -.14,
        .14,
      );
      final height = goal.$2 + BalanceGame.ballRadius;
      final left = height - slope * (goal.$1 - 20),
          right = height + slope * (340 - goal.$1);
      for (var side = 0; side < 2; side++) {
        if (g.pivotTargets[side] == null) g.grabPivot(side);
        g.dragPivot(side, (side == 0 ? left : right) - g.pivotTargets[side]!);
      }
    }
  }
}

CaptureFile recordCompletedLevel() {
  final recorder = CaptureRecorder(const CaptureSetup(level: 1));
  final driver = LevelRecordingDriver();
  for (var tick = 0; tick < captureMaxTicks && !recorder.stopped; tick++) {
    if (tick % 4 == 0) driver.move(recorder.game);
    recorder.step();
  }
  return recorder.snapshot();
}
