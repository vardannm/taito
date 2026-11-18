import 'package:flutter_test/flutter_test.dart';
import 'infinite_boss_test.dart' show run;

void main() {
  test('a slowed ball picks its speed back up smoothly, not in one tick', () {
    // An empty Infinite board: nothing but the platform acts on the ball.
    final game = run()
      ..survival.shield = 1e6
      ..lateEnemiesEnabled = false
      ..snakeEncountersEnabled = false
      ..bossesEnabled = false;
    // A fixed tilt, so only the hands-off slow-down changes the speed.
    game.left -= 40;
    game.ballX = 40;
    game.grabPivot(0);
    for (var i = 0; i < 60; i++) {
      game.step(1 / 120);
    }
    final rolling = game.velocity;
    expect(rolling, greaterThan(40));

    // Hands off: the ball eases down to a crawl.
    game.releasePivot(0);
    for (var i = 0; i < 72; i++) {
      game.step(1 / 120);
    }
    final crawling = game.velocity;
    expect(crawling, lessThan(rolling * .35));

    // Take hold again: no jump on the first tick, and each tick after it
    // gains a little, until the ball is back at full speed.
    game.grabPivot(0);
    game.step(1 / 120);
    expect(game.velocity, lessThan(crawling * 1.25));
    var previous = game.velocity, largestStep = 0.0;
    for (var i = 0; i < 36; i++) {
      game.step(1 / 120);
      expect(game.velocity, greaterThan(previous));
      final step = game.velocity - previous;
      if (step > largestStep) largestStep = step;
      previous = game.velocity;
    }
    // Within a third of a second it is rolling fast again...
    expect(game.velocity, greaterThan(rolling));
    // ...and no single tick supplied more than a small share of that.
    expect(largestStep, lessThan((game.velocity - crawling) * .12));
  });
}
