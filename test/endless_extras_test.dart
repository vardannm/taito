import 'package:balance_arcade/one_finger_controls.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/rewards.dart';

void main() {
  for (final mode in [GameMode.infinite]) {
    test('$mode generates safe random coins and bounds long-run storage', () {
      final layouts = <String>{};
      for (var seed = 0; seed < 12; seed++) {
        final g = BalanceGame(seed: seed)..start(gameMode: mode);
        expect(g.coins, isNotEmpty);
        layouts.add(g.coins.map((c) => '${c.x}/${c.y}').join(','));
        for (var section = 0; section < 80; section++) {
          g.cameraOffset = section * 140.0;
          g.ensureInfiniteBoard();
          g.ensureEndlessExtras();
          expect(g.coins.length, lessThan(12));
          expect(g.spiders.length, lessThan(7));
          for (final c in g.coins) {
            expect(
              g.board.every(
                (h) => math.pow(h.x - c.x, 2) + math.pow(h.y - c.y, 2) >= 900,
              ),
              true,
            );
          }
        }
      }
      expect(layouts.length, 12);
    });
    test(
      '$mode collects once, preserves metres and resets coins on replay',
      () {
        final g = BalanceGame(seed: 3)..start(gameMode: mode);
        g.board.clear();
        g.spiders.clear();
        final coin = BrassCoin(g.ballX, g.ballY);
        g.coins
          ..clear()
          ..add(coin);
        g.step(1 / 120);
        expect(g.coinsCollected, 1);
        expect(coin.collected, true);
        expect(g.event, GameEvent.coin);
        expect(g.score, 0);
        g.step(1 / 120);
        expect(g.coinsCollected, 1);
        g.start(gameMode: mode);
        expect(g.coinsCollected, 0);
        expect(g.coins.every((c) => !c.collected), true);
      },
    );
  }

  test('pause freezes coins, camera and pending manual lift', () {
    final g = BalanceGame(seed: 3)
      ..setControlMode(ControlMode.oneFinger)
      ..start(gameMode: GameMode.infinite);
    final c = g.coins.first;
    final coinY = c.y, left = g.left;
    g.grabControl();
    g.dragControlVertical(-60);
    g.setPaused(true);
    g.step(.1);
    expect((c.y, g.left), (coinY, left));
    expect(g.controlHeld, false);
    g.setPaused(false);
    g.step(1 / 120);
    expect(g.left, closeTo(left, 1));
  });

  testWidgets(
    'one finger controls tilt and lift, ignores a second finger and cancels safely',
    (tester) async {
      final g = BalanceGame()
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: GameMode.merge2048);
      g.mergeRun.orbs.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 560,
              child: PivotBoard(game: g, frame: frame),
            ),
          ),
        ),
      );
      final pad = find.byType(OneFingerControls);
      final origin = tester.getCenter(pad);
      final scale = tester.widget<OneFingerControls>(pad).boardScale;
      final finger = await tester.startGesture(origin, pointer: 1);
      final extra = await tester.startGesture(origin, pointer: 2);
      await extra.moveBy(const Offset(0, -100));
      expect(g.controlPosition, 0);
      await finger.moveBy(Offset(22 * scale, -30 * scale));
      g.step(1 / 120);
      expect(g.controlPosition, closeTo(.2, .001));
      expect((g.left + g.right) / 2, closeTo(470, .001));
      expect(g.right - g.left, closeTo(28, .001));
      await finger.moveBy(Offset(0, 15 * scale));
      g.step(1 / 120);
      expect((g.left + g.right) / 2, closeTo(485, .001));
      g.setPaused(true);
      await finger.moveBy(const Offset(0, -100));
      g.setPaused(false);
      g.step(1 / 120);
      expect((g.left + g.right) / 2, closeTo(485, .001));
      await finger.cancel();
      await extra.up();
      expect(g.controlHeld, false);
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    },
  );
}
