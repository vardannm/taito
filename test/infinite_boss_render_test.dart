import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/infinite_boss_painter.dart';
import 'combo_render_budget_test.dart' show DrawingBudget;

void main() {
  for (final kind in BossKind.values) {
    test(
      '$kind renders every phase with bounded work and no blur or layers',
      () {
        for (final reducedMotion in [false, true]) {
          final game = BalanceGame()..start(gameMode: GameMode.infinite);
          final boss = InfiniteBoss(kind: kind);
          game.boss = boss;
          for (var frame = 0; frame < 28 * 60; frame++) {
            boss.step(1 / 60, target: (x: 180, y: 420), scrollDistance: 2);
            final age = boss.age;
            final shotAges = boss.shots.map((shot) => shot.age).toList();
            final budget = DrawingBudget();
            paintInfiniteBoss(budget, game, reducedMotion);
            expect(budget.draws, lessThanOrEqualTo(65));
            expect(budget.blurs, 0);
            expect(budget.layers, 0);
            expect(boss.age, age);
            expect(boss.shots.map((shot) => shot.age), shotAges);
          }
        }
      },
    );
  }
}
