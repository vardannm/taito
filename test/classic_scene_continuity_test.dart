import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_test.dart' show advance, placeAt;

void main() {
  test(
    'laser motion and age continue through sinking and the complete return',
    () {
      final game = BalanceGame()..start(levelNumber: 61);
      game.board
        ..clear()
        ..addAll([
          const Hole(300, 450, target: 1),
          const Hole(260, 200, target: 2),
        ]);
      game.coins.clear();
      final laser = SpecialHazard(
        HazardKind.laser,
        x: 90,
        y: 250,
        warningSeconds: 0,
        liveSeconds: 30,
        motion: HazardMotion.horizontal,
        radiusX: 24,
        period: 5,
      );
      game.specialHazards.add(laser);
      placeAt(game, game.activeHole!);
      expect(game.target, 2);
      expect(game.phase, GamePhase.sinking);
      final elapsed = game.elapsed;
      advance(game, .4);
      expect(laser.age, closeTo(.4, .01));
      expect(laser.x, isNot(90));
      final age = laser.age;
      game.setPaused(true);
      advance(game, 1);
      expect(laser.age, age);
      game.setPaused(false);
      advance(game, 1);
      expect(game.phase, GamePhase.playing);
      expect(game.specialHazards.single, same(laser));
      expect(laser.age, closeTo(1.4, .02));
      expect(game.lives, 3);
      expect(game.elapsed - elapsed, lessThan(.1));
      game.start(levelNumber: 61);
      expect(game.specialHazards, isEmpty);
    },
  );

  test(
    'the wave schedule continues during the return rather than restarting per hole',
    () {
      final game = BalanceGame()..start(levelNumber: 10);
      game.board
        ..clear()
        ..addAll([
          const Hole(300, 450, target: 1),
          const Hole(260, 200, target: 2),
        ]);
      game.coins.clear();
      advance(game, ClassicLevels.definition(10).firstHazardAfter - .2);
      expect(game.specialHazards, isEmpty);
      placeAt(game, game.activeHole!);
      advance(game, .4);
      expect(game.specialHazards, hasLength(1));
      final laser = game.specialHazards.single;
      expect(laser.warning, isTrue);
      advance(game, 1);
      expect(game.phase, GamePhase.playing);
      expect(game.specialHazards.single, same(laser));
      expect(laser.age, greaterThan(1));
      advance(game, laser.warningSeconds - laser.age + .05);
      expect(laser.active, isTrue);
      expect(game.lives, 3);
    },
  );

  test(
    'spiders retain chase progress and keep moving while the ball returns',
    () {
      final game = BalanceGame()..start(levelNumber: 31);
      final spider = game.spiders.first;
      spider.chasing = true;
      placeAt(game, game.activeHole!);
      expect(game.phase, GamePhase.sinking);
      final x = spider.x, y = spider.y, time = spider.time;
      advance(game, .2);
      expect(spider.time, greaterThan(time));
      expect((spider.x, spider.y), isNot((x, y)));
      advance(game, 1.2);
      expect(game.phase, GamePhase.playing);
      expect(game.spiders.first, same(spider));
      expect(spider.chasing, isTrue);
      expect(spider.time, greaterThan(1.4));
      expect(game.lives, 3);
      game.start(levelNumber: 31);
      expect(game.spiders.first.time, 0);
      expect(game.spiders.first.chasing, isFalse);
    },
  );

  test(
    'a live beam overlapping the respawn cannot take a life before separation',
    () {
      final game = BalanceGame()..start(levelNumber: 10);
      game.board
        ..clear()
        ..add(const Hole(300, 450, target: 1));
      game.coins.clear();
      final laser = SpecialHazard(
        HazardKind.laser,
        x: 180,
        y: 250,
        warningSeconds: 0,
        liveSeconds: 30,
      );
      game.specialHazards.add(laser);
      placeAt(game, game.activeHole!);
      advance(game, 1.5);
      expect(game.phase, GamePhase.playing);
      expect(game.lives, 3);
      expect(game.specialHazards.single, same(laser));
      game.ballX = 140;
      game.step(1 / 120);
      game.ballX = 180;
      game.step(1 / 120);
      expect(game.lives, 2);
      expect(game.phase, GamePhase.sinking);
    },
  );
}
