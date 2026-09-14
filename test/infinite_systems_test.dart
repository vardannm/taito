import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

BalanceGame run() => BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
void pickup(BalanceGame g, InfiniteItemKind kind) {
  g.board.clear();
  g.specialHazards.clear();
  g.survival.items.add(InfiniteItem(kind, g.ballX, g.ballY));
  g.step(1 / 120);
}

void hit(BalanceGame g) {
  g.board.clear();
  g.board.add(Hole(g.ballX, g.ballY));
  g.step(1 / 120);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'three hits cost one heart each, clear inputs, recover safely and finally end the run',
    () {
      final g = run();
      final serial = g.runSerial;
      for (var remaining = 2; remaining >= 0; remaining--) {
        g.survival.recovery = 0;
        g.survival.combo = 5;
        g.survival.visualCombo = 1;
        g.grabPivot(0);
        g.grabPivot(1);
        hit(g);
        expect(g.lives, remaining);
        expect(g.runSerial, serial);
        expect(g.survival.combo, 1);
        expect(g.survival.visualCombo, 0);
        expect(g.pivotTargets.every((target) => target == null), true);
        if (remaining > 0) {
          expect(g.phase, GamePhase.playing);
          expect(g.left, g.right);
          expect(g.screenY(g.left), inInclusiveRange(67, 497));
          expect(g.survival.recovery, 2.5);
          expect(
            g.board.every(
              (h) =>
                  math.pow(h.x - g.ballX, 2) + math.pow(h.y - g.ballY, 2) >=
                  30 * 30,
            ),
            true,
          );
          hit(g);
          expect(g.lives, remaining);
        } else {
          expect(g.phase, GamePhase.sinking);
          for (var i = 0; i < 90; i++) {
            g.step(1 / 120);
          }
          expect(g.finished, true);
        }
      }
      expect(g.misses, 3);
      g.start(gameMode: GameMode.infinite);
      expect(g.lives, 3);
      expect(g.survival.protected, false);
      expect(g.score, 0);
    },
  );
  test(
    'combo crystals award increasing points once, cap at five and survive missed items',
    () {
      final g = run();
      var total = 0;
      for (var i = 0; i < 6; i++) {
        pickup(g, InfiniteItemKind.combo);
        final combo = math.min(5, i + 2);
        total += 50 * combo;
        expect(g.survival.combo, combo);
        expect(g.score, total);
      }
      final score = g.score;
      g.step(1 / 120);
      expect(g.score, score);
      g.survival.items.add(InfiniteItem(InfiniteItemKind.combo, 40, 650));
      g.step(1 / 120);
      expect(g.survival.combo, 5);
      expect(g.survival.items.any((i) => i.y == 650), false);
    },
  );
  test(
    'shield lasts ten active seconds, pause freezes timers, hits preserve combo',
    () {
      final g = run();
      pickup(g, InfiniteItemKind.combo);
      pickup(g, InfiniteItemKind.shield);
      expect(g.survival.shield, 10);
      hit(g);
      expect(g.lives, 3);
      expect(g.survival.combo, 2);
      final shield = g.survival.shield;
      g.setPaused(true);
      for (var i = 0; i < 200; i++) {
        g.step(.05);
      }
      expect(g.survival.shield, shield);
      g.setPaused(false);
      for (var i = 0; i < 1200; i++) {
        g.board.clear();
        g.specialHazards.clear();
        g.survival.items.clear();
        g.stallTime = 0;
        g.step(1 / 120);
      }
      expect(g.survival.shield, 0);
      hit(g);
      expect(g.lives, 2);
      expect(g.survival.combo, 1);
    },
  );
  for (final kind in HazardKind.values) {
    test('shield blocks $kind and recovery remains independent', () {
      final g = run();
      pickup(g, InfiniteItemKind.shield);
      g.survival.combo = 5;
      g.specialHazards.add(
        SpecialHazard(
          kind,
          x: g.ballX,
          y: g.screenY(g.ballY),
          warningSeconds: 0,
        ),
      );
      g.step(1 / 120);
      expect(g.lives, 3);
      expect(g.survival.combo, 5);
      g.survival.shield = 0;
      g.survival.recovery = 2.5;
      g.step(1 / 120);
      expect(g.lives, 3);
    });
  }
  test('shield blocks the rising floor', () {
    final g = run();
    pickup(g, InfiniteItemKind.shield);
    g.dangerY = g.ballY;
    g.step(1 / 120);
    expect(g.lives, 3);
  });
  for (final shieldFirst in [true, false]) {
    test(
      'fast swipe resolves shield ${shieldFirst ? 'before' : 'after'} hole in travel order',
      () {
        final g = run();
        g.board.clear();
        g.survival.items.clear();
        g.board.add(const Hole(180, 350));
        g.survival.items.add(
          InfiniteItem(InfiniteItemKind.shield, 180, shieldFirst ? 400 : 300),
        );
        g.grabPivot(0);
        g.grabPivot(1);
        g.dragPivot(0, -200);
        g.dragPivot(1, -200);
        g.step(1 / 120);
        expect(g.lives, shieldFirst ? 3 : 2);
        expect(g.survival.shield > 0, shieldFirst);
      },
    );
  }
  for (final shieldFirst in [true, false]) {
    test(
      'moving hazard and shield use the same swept timeline ($shieldFirst)',
      () {
        final g = run();
        g.board.clear();
        g.survival.items.clear();
        g.specialHazards.add(
          SpecialHazard(
            HazardKind.formingHole,
            x: 180,
            y: 350,
            warningSeconds: 0,
          ),
        );
        g.survival.items.add(
          InfiniteItem(InfiniteItemKind.shield, 180, shieldFirst ? 400 : 300),
        );
        g.grabPivot(0);
        g.grabPivot(1);
        g.dragPivot(0, -200);
        g.dragPivot(1, -200);
        g.step(1 / 120);
        expect(g.lives, shieldFirst ? 3 : 2);
      },
    );
  }
  test(
    'hearts restore a life up to three; a full-health pickup becomes points',
    () {
      final g = run()..lives = 1;
      pickup(g, InfiniteItemKind.heart);
      expect(g.lives, 2);
      pickup(g, InfiniteItemKind.heart);
      expect(g.lives, 3);
      final score = g.score;
      pickup(g, InfiniteItemKind.heart);
      expect(g.lives, 3);
      expect(g.score, score + 50);
    },
  );
  test(
    'pace is continuous, capped, and experienced starts remain moderate',
    () {
      expect(InfiniteTuning.startingPace(149), 1);
      expect(InfiniteTuning.startingPace(150), 2);
      expect(InfiniteTuning.startingPace(450), 3);
      final g = run();
      g.maxHeight = 1499.9;
      final before = g.ascentSpeed;
      g.maxHeight = 1500.1;
      expect(g.paceLevel, 2);
      expect(g.ascentSpeed - before, lessThan(.01));
      g.maxHeight = 90000;
      expect(g.paceLevel, 5);
      expect(g.ascentSpeed, 216);
      g.infiniteStartingPace = 3;
      g.start(gameMode: GameMode.infinite);
      expect(g.paceLevel, 3);
      expect(g.ascentSpeed, 86);
      g.survival.points = 100000;
      g.step(1 / 120);
      expect(g.specialHazards, isEmpty);
      expect(g.paceLevel, 3);
    },
  );
  test(
    'generated pickups remain bounded, clear of holes, with rarer shields and conditional hearts',
    () {
      for (final missingHeart in [true, false]) {
        final g = run();
        if (missingHeart) g.lives = 2;
        final seen = <InfiniteItem>{};
        for (var i = 0; i < 550; i++) {
          g.cameraOffset = i * 60.0;
          g.left = g.right = 440 - g.cameraOffset;
          g.stallTime = 0;
          g.survival.shield = 100;
          g.step(1 / 120);
          seen.addAll(g.survival.items);
          expect(
            g.survival.items.length,
            lessThanOrEqualTo(InfiniteTuning.maxItems),
          );
          for (final item in g.survival.items) {
            expect(item.x, inInclusiveRange(45, 315));
            expect(
              g.board.every(
                (h) =>
                    math.pow(h.x - item.x, 2) + math.pow(h.y - item.y, 2) >=
                    32 * 32,
              ),
              true,
            );
          }
        }
        final combos = seen
            .where((i) => i.kind == InfiniteItemKind.combo)
            .length;
        final shields = seen
            .where((i) => i.kind == InfiniteItemKind.shield)
            .length;
        final hearts = seen
            .where((i) => i.kind == InfiniteItemKind.heart)
            .length;
        expect(combos, greaterThan(shields * 4));
        expect(shields, greaterThan(2));
        expect(hearts, missingHeart ? greaterThan(0) : 0);
        expect(hearts, lessThan(shields));
      }
    },
  );
  test(
    'wallet deposits are idempotent across frames and runs and purchases persist',
    () async {
      final p = PlayerProfile();
      final g = run()..coinsCollected = 100;
      expect(p.bankCoins(g), true);
      expect(p.bankCoins(g), false);
      expect(p.wallet, 100);
      expect(p.selectBall(BallCosmetic.neon), true);
      expect(p.wallet, 0);
      expect(p.selectBall(BallCosmetic.reactor), false);
      g.coinsCollected = 105;
      p.bankCoins(g);
      expect(p.wallet, 5);
      p.selectBall(BallCosmetic.steel);
      p.selectBall(BallCosmetic.neon);
      expect(p.wallet, 5);
      g.start(gameMode: GameMode.mazeEndless);
      g.coinsCollected = 3;
      p.bankCoins(g);
      await p.saveEconomy();
      final loaded = PlayerProfile();
      await loaded.load();
      expect(loaded.wallet, 8);
      expect(loaded.selectedBall, BallCosmetic.neon);
      expect(loaded.ownedBalls, contains(BallCosmetic.neon));
      g.start();
      g.coinsCollected = 99;
      expect(p.bankCoins(g), false);
    },
  );
  test(
    'malformed saved economy cannot select an unowned ball or give negative coins',
    () async {
      await SharedPreferencesAsync().setString(
        'gilt.economy.v1',
        '{"wallet":-100,"owned":["missing"],"selected":"reactor"}',
      );
      final p = PlayerProfile();
      await p.load();
      expect(p.wallet, 0);
      expect(p.selectedBall, BallCosmetic.steel);
    },
  );
  test('cosmetic selection never changes physics or collision', () {
    final reference = run();
    reference.board.clear();
    reference.survival.shield = 100;
    reference.leftInput = -1;
    reference.step(.1);
    for (final ball in BallCosmetic.values) {
      final g = run()..cosmetic = ball;
      g.board.clear();
      g.survival.shield = 100;
      g.leftInput = -1;
      g.step(.1);
      expect(
        (g.ballX, g.ballY, g.velocity, g.lives),
        (reference.ballX, reference.ballY, reference.velocity, reference.lives),
      );
    }
  });
  testWidgets(
    'small-screen shop unlocks, equips and rejects unaffordable purchases',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlayerProfile()..wallet = 40;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BallShop(profile: p)),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-coral')).hitTestable(),
        140,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('buy-coral')));
      await tester.pump();
      expect(p.wallet, 5);
      expect(p.selectedBall, BallCosmetic.coral);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-neon')).hitTestable(),
        160,
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-neon')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await p.saveEconomy();
    },
  );
}
