import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(1032, 1376),
    const Size(1376, 1032),
    const Size(1114, 720),
    const Size(402, 874),
  ]) {
    test('phone-recorded bosses stay inside replay viewport at $size', () {
      const recordedTop = -130.4615384615385;
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      final view = BoardViewport.forGame(
        size,
        game,
        fillWidth: 1,
        contentTop: recordedTop,
      );
      expect(
        view.project(const Offset(180, recordedTop)).dy,
        greaterThanOrEqualTo(view.bounds.top - .001),
      );
      for (final kind in BossKind.values) {
        final boss = InfiniteBoss(top: recordedTop, kind: kind)
          ..step(3, target: (x: 180, y: 400));
        final center = Offset(boss.position.x, boss.position.y);
        expect(
          view.project(center - const Offset(0, 65)).dy,
          greaterThanOrEqualTo(view.bounds.top),
          reason: kind.name,
        );
        expect(
          view.project(center + const Offset(0, 65)).dy,
          lessThan(view.bounds.bottom),
          reason: kind.name,
        );
      }
    });
  }
}
