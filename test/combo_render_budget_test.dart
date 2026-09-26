import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_painter.dart';

class DrawingBudget implements Canvas {
  int draws = 0, blurs = 0, layers = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) draws++;
    if (invocation.memberName == #saveLayer) layers++;
    for (final argument in invocation.positionalArguments) {
      if (argument is Paint && argument.maskFilter != null) blurs++;
    }
    return null;
  }
}

void main() {
  for (final combo in [4, 5, 20, 100]) {
    test(
      'combo $combo uses bounded draws without blur passes or offscreen layers',
      () {
        final game = BalanceGame()..start(gameMode: GameMode.infinite);
        game.survival.combo = combo;
        game.survival.visualCombo = 1;
        game.maxHeight = 100000;
        for (final time in [0.0, 1.0, 10000.0]) {
          game.clock = time;
          final canvas = DrawingBudget();
          paintInfiniteAtmosphere(canvas, game, false);
          paintInfiniteEnergy(canvas, game, false);
          expect(canvas.draws, lessThanOrEqualTo(32));
          expect(canvas.blurs, 0);
          expect(canvas.layers, 0);
        }
        final still = DrawingBudget();
        paintInfiniteAtmosphere(still, game, true);
        paintInfiniteEnergy(still, game, true);
        expect(still.draws, lessThanOrEqualTo(4));
        expect(still.blurs, 0);
      },
    );
  }
}
