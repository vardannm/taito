import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';

void main() {
  test(
    'scattered holes occupy the whole board without aligned pairs or overlaps',
    () {
      final zones = [0, 0, 0];
      var consecutiveSameSide = 0, consecutive = 0;
      for (var seed = 0; seed < 60; seed++) {
        final game = BalanceGame(seed: seed)
          ..start(gameMode: GameMode.infinite);
        for (final height in [0, 180, 600, 1200]) {
          game.cameraOffset = height * 10.0;
          game.ensureInfiniteBoard();
          final holes = game.board.toList()..sort((a, b) => a.y.compareTo(b.y));
          expect(holes.any((h) => h.x < 180), isTrue);
          expect(holes.any((h) => h.x > 180), isTrue);
          for (var i = 0; i < holes.length; i++) {
            final h = holes[i];
            zones[((h.x - 28) / 102).floor().clamp(0, 2)]++;
            if (i > 0) {
              consecutive++;
              if ((h.x < 180) == (holes[i - 1].x < 180)) consecutiveSameSide++;
            }
            for (var j = i + 1; j < holes.length; j++) {
              expect((h.y - holes[j].y).abs(), greaterThan(12));
              expect(
                math.pow(h.x - holes[j].x, 2) + math.pow(h.y - holes[j].y, 2),
                greaterThan(36 * 36),
              );
            }
          }
        }
      }
      final total = zones.reduce((a, b) => a + b);
      for (final count in zones) {
        expect(count / total, greaterThan(.14));
      }
      expect(consecutiveSameSide / consecutive, lessThan(.8));
    },
  );
}
