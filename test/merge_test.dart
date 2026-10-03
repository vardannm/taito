import 'support/mode_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/merge.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/merge_widgets.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

MergeRun emptyRun({int seed = 1}) => MergeRun(seed: seed)
  ..orbs.clear()
  ..gates.clear();

void clearStream(BalanceGame game) {
  game.mergeRun.orbs.clear();
  game.mergeRun.gates.clear();
}

List<int> fullSnake() =>
    List.generate(MergeRun.maxSegments, (i) => 1 << (MergeRun.maxSegments - i));

/// The generated geometry a carousel preview shows for [mode].
List<double> layoutOf(BalanceGame game, GameMode mode) => switch (mode) {
  GameMode.merge2048 => [
    for (final orb in game.mergeRun.orbs) ...[orb.x, orb.y, orb.value + .0],
  ],
  _ => [
    for (final hole in game.board) ...[hole.x, hole.y],
  ],
};

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('every waiting carousel board matches the baked layout, then varies', () {
    for (final mode in [GameMode.merge2048, GameMode.infinite]) {
      // The bake tool renders seed 711; a live engine has consumed unknown
      // randomness by the time the player swipes back to the mode.
      final baked = BalanceGame(seed: 711)
        ..start(gameMode: mode, waitForInput: true);
      final used = BalanceGame(seed: 4242)
        ..start(gameMode: GameMode.infinite, waitForInput: true)
        ..start(gameMode: GameMode.classic, levelNumber: 7)
        ..start(gameMode: mode, waitForInput: true);
      expect(layoutOf(used, mode), layoutOf(baked, mode), reason: '$mode');
      // The run itself is not the preview: the first touch draws a new course.
      final varied = <List<double>>{};
      for (final seed in [1, 2, 3, 4]) {
        final game = BalanceGame(seed: seed)
          ..start(gameMode: mode, waitForInput: true)
          ..beginInput();
        varied.add(layoutOf(game, mode));
      }
      expect(varied.length, greaterThan(1), reason: '$mode');
    }
  });

  test('descending tail cascades to 64 with another 2', () {
    final run = emptyRun()..segments.insert(0, 32);
    for (final value in [16, 8, 4]) {
      run.collect(value);
      expect(run.head, 32);
      expect(run.segmentX(180, 0), 180);
    }
    expect(run.segments, [32, 16, 8, 4, 2]);
    for (var i = 1; i < run.segments.length; i++) {
      expect(run.segmentX(180, i), 180);
      expect(run.segmentY(300, i), greaterThan(run.segmentY(300, i - 1)));
      expect(run.segmentRadius(i), lessThan(run.segmentRadius(i - 1)));
    }
    run.collect(2);
    expect(run.segments, [64]);
    expect(run.lastChain, 5);
    expect(run.lastMergeScore, 124);
    expect(run.score, 124);
    expect(run.ended, false);
  });
  test(
    'matching any number merges across the snake, not only the smallest',
    () {
      final run = emptyRun();
      run.segments
        ..clear()
        ..addAll([64, 32, 16, 2]);
      expect(run.canMerge(32), true);
      expect(run.canMerge(8), false);
      run.collect(32);
      expect(run.segments, [128, 16, 2]);
      expect(run.head, 128);
      expect(run.tail, 2);
      expect(run.lastChain, 2);
      expect(run.score, 192);
    },
  );
  test('4 leads and a smaller 2 attaches below before merging to 8', () {
    final run = emptyRun()..collect(2);
    run.collect(2);
    expect(run.segments, [4, 2]);
    expect(run.segmentY(300, 0), 300);
    expect(run.segmentY(300, 1), greaterThan(300));
    run.collect(2);
    expect(run.segments, [8]);
    expect(run.lastMergeScore, 12);
  });
  test('every length grows downward with the biggest at the head', () {
    final run = emptyRun();
    for (var count = 1; count <= MergeRun.maxSegments; count++) {
      run.segments
        ..clear()
        ..addAll(List.generate(count, (i) => 1 << (count - i)));
      for (var i = 0; i < count; i++) {
        expect(run.segmentX(180, i), 180);
        expect(run.segmentY(200, i), 200 + i * run.spacing);
      }
      expect(run.head, 1 << count);
      expect(run.length, lessThanOrEqualTo(MergeRun.platformWidth));
      expect(run.minHeadX, lessThanOrEqualTo(run.maxHeadX));
    }
  });
  test('long snakes compress and never lose to platform capacity', () {
    final run = emptyRun();
    run.segments
      ..clear()
      ..add(32768);
    for (var value = 16384; value >= 2; value ~/= 2) {
      run.collect(value);
      expect(run.ended, false);
      expect(run.minHeadX, lessThanOrEqualTo(run.maxHeadX));
    }
    expect(run.segments.length, 15);
    expect(run.length, lessThanOrEqualTo(MergeRun.platformWidth));
    run.collect(2);
    expect(run.segments, [65536]);
  });
  test('matching 2 rescues a full snake into 8192 without a win stop', () {
    final run = emptyRun();
    run.segments
      ..clear()
      ..addAll(fullSnake());
    run.collect(2);
    expect(run.segments, [8192]);
    expect(run.lastChain, 12);
    expect(run.ended, false);
  });
  test('turns propagate down the tail and settle when the head stops', () {
    final run = emptyRun();
    run.segments
      ..clear()
      ..addAll([32, 16, 8, 4, 2]);
    run.step(1 / 60, 180, 100, 180, 100);
    run.step(1 / 60, 180, 100, 192, 100);
    expect(run.segmentX(192, 1), lessThan(192));
    expect(run.segmentX(192, 1), greaterThan(run.segmentX(192, 4)));
    for (var i = 0; i < 180; i++) {
      run.orbs.clear();
      run.step(1 / 60, 192, 100, 192, 100);
    }
    expect(run.segmentX(192, 4), closeTo(192, .01));
    run.collect(2);
    expect(run.segments, [64]);
    run.step(1 / 60, 90, 100, 90, 100);
    run.collect(2);
    expect(run.segmentX(90, 1), 90);
  });
  test('tail motion stays bounded at both edges and after a reversal', () {
    final run = emptyRun();
    run.segments
      ..clear()
      ..addAll(fullSnake());
    for (final x in [32.0, 328.0, 32.0]) {
      run.step(1 / 60, 180, 100, x, 100);
      for (var i = 1; i < run.segments.length; i++) {
        expect(
          run.segmentX(x, i),
          inInclusiveRange(run.minHeadX, run.maxHeadX),
        );
        expect(
          (run.segmentX(x, i) - run.segmentX(x, i - 1)).abs(),
          lessThanOrEqualTo(run.spacing * .65 + .001),
        );
      }
    }
  });
  test('the full tail fits below the platform for every control mode', () {
    for (final control in ControlMode.values) {
      final g = BalanceGame()
        ..preferredControlMode = control
        ..start(gameMode: GameMode.merge2048);
      clearStream(g);
      g.mergeRun.segments
        ..clear()
        ..addAll(fullSnake());
      g.step(1 / 120);
      final run = g.mergeRun;
      expect(
        run.segmentY(g.ballY, run.segments.length - 1) +
            run.segmentRadius(run.segments.length - 1),
        lessThan(550),
      );
      for (final size in [const Size(320, 300), const Size(390, 580)]) {
        final viewport = BoardViewport.forGame(size, g, fillWidth: 1);
        final tailBottom = viewport.project(
          Offset(
            g.ballX,
            g.ballY +
                run.tailExtent +
                run.segmentRadius(run.segments.length - 1),
          ),
        );
        expect(tailBottom.dy, lessThan(size.height));
        expect(
          viewport.project(Offset(g.ballX, g.ballY - MergeRun.ballRadius)).dy,
          greaterThan(0),
        );
      }
      expect(g.finished, false);
    }
  });
  test('large number labels use binary thousands and millions', () {
    for (final entry in {
      2: '2',
      512: '512',
      1024: '1k',
      2048: '2k',
      4096: '4k',
      524288: '512k',
      1048576: '1m',
      2097152: '2m',
      1073741824: '1b',
    }.entries) {
      expect(formatMergeNumber(entry.key), entry.value);
    }
  });
  test('each wave has reachable food and a separated larger hazard', () {
    for (var seed = 0; seed < 40; seed++) {
      final run = MergeRun(seed: seed);
      expect(run.orbs.length, 9);
      for (var row = 0; row < 3; row++) {
        final wave = run.orbs.skip(row * 3).take(3).toList();
        expect(wave[0].value, run.tail);
        expect(wave[1].value, lessThanOrEqualTo(run.head));
        expect(wave[2].value, greaterThan(run.head));
        expect(wave[0].x, inInclusiveRange(run.minHeadX, run.maxHeadX));
        for (var a = 0; a < 3; a++) {
          for (var b = a + 1; b < 3; b++) {
            expect((wave[a].x - wave[b].x).abs(), greaterThanOrEqualTo(60));
          }
        }
      }
      for (var i = 0; i < 200; i++) run.step(.1, -100, -100, -100, -100);
      expect(run.ended, false);
      expect(run.orbs.length, lessThan(22));
    }
  });
  test('only the head collects; tail passes through dangerous numbers', () {
    final g = BalanceGame()..start(gameMode: GameMode.merge2048);
    clearStream(g);
    g.mergeRun.segments
      ..clear()
      ..addAll([16, 8, 4, 2]);
    g.left = g.right = 400;
    final ghostX = g.mergeRun.segmentX(g.ballX, 3);
    g.mergeRun.orbs.add(NumberOrb(ghostX, g.mergeRun.segmentY(g.ballY, 3), 32));

    g.step(1 / 120);
    expect(g.mergeRun.segments, [16, 8, 4, 2]);
    expect(g.mergeRun.orbs.length, 1);
    expect(g.finished, false);
    clearStream(g);
    g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, 2));
    g.step(1 / 120);
    expect(g.mergeRun.segments, [32]);
  });
  test(
    'equal and smaller numbers are safe; larger numbers end immediately',
    () {
      final run = emptyRun()..segments[0] = 8;
      run.collect(4);
      expect(run.segments, [8, 4]);
      run.collect(8);
      expect(run.segments, [16, 4]);
      final score = run.score;
      run.collect(32);
      expect(run.rejectedValue, 32);
      expect(run.score, score);
      expect(run.segments, [16, 4]);
    },
  );
  test('a merge before a later large pickup can make it safe', () {
    final run = emptyRun();
    run.orbs.addAll([NumberOrb(180, 470, 2), NumberOrb(180, 380, 4)]);
    run.step(1 / 120, 180, 520, 180, 320);
    expect(run.ended, false);
    expect(run.head, 8);
  });
  test('dangerous pickup stops all later pickups in a fast swipe', () {
    final run = emptyRun();
    run.orbs.addAll([NumberOrb(180, 470, 4), NumberOrb(180, 380, 2)]);
    run.step(1 / 120, 180, 520, 180, 320);
    expect(run.rejectedValue, 4);
    expect(run.collected, 0);
    expect(run.orbs.single.value, 2);
  });
  test(
    'gates require strictly more, including swept crossing in either direction',
    () {
      for (final head in [32, 64, 128]) {
        for (final upwards in [false, true]) {
          final run = emptyRun()..segments[0] = head;
          run.gates.add(MergeGate(64, y: 300));
          run.step(1 / 120, 180, upwards ? 400 : 200, 180, upwards ? 200 : 400);
          expect(run.ended, head <= 64);
          expect(run.gatesPassed, head > 64 ? 1 : 0);
        }
      }
    },
  );
  test(
    'descending gate reaches a stationary ball and checks the current head',
    () {
      final run = emptyRun()..segments[0] = 64;
      run.gates.add(MergeGate(64, y: 270));
      run.step(1, 180, 300, 180, 300);
      expect(run.failedGate, 64);
    },
  );
  test('pickups resolve before a later gate but not after an earlier gate', () {
    final run = emptyRun()..segments[0] = 64;
    run.orbs.add(NumberOrb(180, 450, 64));
    run.gates.add(MergeGate(64, y: 350));
    run.step(1 / 120, 180, 520, 180, 280);
    expect(run.head, 128);
    expect(run.gatesPassed, 1);
    final failed = emptyRun()..segments[0] = 64;
    failed.orbs.add(NumberOrb(180, 350, 64));
    failed.gates.add(MergeGate(64, y: 450));
    failed.step(1 / 120, 180, 520, 180, 280);
    expect(failed.failedGate, 64);
    expect(failed.collected, 0);
  });
  test(
    '400-point milestones queue exactly once with only one gate on screen',
    () {
      final run = emptyRun()..score = 399;
      run.step(.01, 180, 500, 180, 500);
      expect(run.gates, isEmpty);
      run.score = 1200;
      run.step(.01, 180, 500, 180, 500);
      expect(run.gates.single.scoreAt, 400);
      expect(run.gates.single.y, lessThan(0));
      expect(run.pendingGates, 2);
      run.segments[0] = 1024;
      for (final scoreAt in [400, 800, 1200]) {
        expect(run.gates.single.scoreAt, scoreAt);
        run.gates.single.y = 500;
        run.step(.01, 180, 500, 180, 500);
        for (var i = 0; i < 13; i++) run.step(.1, 180, 500, 180, 500);
      }
      expect(run.gatesPassed, 3);
      expect(run.gates, isEmpty);
      expect(run.nextGateScore, 1600);
      expect(MergeRun.gateValueAt(400), 128);
      expect(MergeRun.gateValueAt(16400), 8192);
      expect(MergeRun.gateValueAt(4398046511104), 2199023255552);
    },
  );
  test(
    '2048 and later merges keep simulation, input, and records in one run',
    () async {
      final g = BalanceGame()..start(gameMode: GameMode.merge2048);
      clearStream(g);
      final p = PlayerProfile();
      g.mergeRun.segments
        ..clear()
        ..add(1024);
      final epoch = g.inputEpoch;
      final serial = g.runSerial;
      for (final value in [1024, 2048]) {
        g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, value));
        g.step(1 / 120);
        expect(g.finished, false);
        expect(g.won, false);
        expect(g.canControl, true);
        expect(g.event, GameEvent.merge);
        expect(g.inputEpoch, epoch);
        expect(g.runSerial, serial);
      }
      expect(g.mergeRun.head, 4096);
      expect(p.recordResult(g), false);
      expect(p.mergeRuns, 0);
      g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, g.mergeRun.head * 2));
      g.step(1 / 120);
      expect(g.finished, true);
      expect(g.lives, 0);
      expect(g.earnedStarMask, 0);
      p.recordResult(g);
      p.recordResult(g);
      expect(p.mergeRuns, 1);
      expect(p.mergeHighest, 4096);
      expect(p.mergeBest, 6144);
      expect(p.runs, 0);
      expect(p.totalStars, 0);
      await p.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.mergeBest, 6144);
      expect(restored.mergeHighest, 4096);
      expect(restored.mergeRuns, 1);
      g.start(gameMode: GameMode.merge2048);
      expect(g.mergeRun.segments, [2]);
      expect(g.mergeRun.ended, false);
      expect(g.score, 0);
    },
  );
  for (final control in ControlMode.values) {
    test('centered snake slides, tilts, and fits both ends with $control', () {
      final g = BalanceGame()
        ..setControlMode(control)
        ..start(gameMode: GameMode.merge2048);
      clearStream(g);
      g.mergeRun.segments
        ..clear()
        ..addAll([32, 16, 8, 4, 2]);
      g.left = 400;
      g.right = 470;
      g.controlPosition = .5;
      g.ballX = 230;
      g.velocity = 100;
      final before = g.ballX;
      g.step(.1);
      expect(g.ballX, greaterThan(before));
      expect(g.mergeRun.segmentX(g.ballX, 0), g.ballX);
      expect(
        g.ballY,
        closeTo(g.platformY(g.ballX) - MergeRun.ballRadius, .001),
      );
      // Collected segments never shorten the head's reach: it still travels to
      // either edge of the platform while the tail trails below.
      expect(g.mergeRun.minHeadX, MergeRun.platformLeft + MergeRun.ballRadius);
      expect(g.mergeRun.maxHeadX, MergeRun.platformRight - MergeRun.ballRadius);
      for (final direction in [-1, 1]) {
        g.ballX = direction < 0 ? g.mergeRun.minHeadX : g.mergeRun.maxHeadX;
        g.velocity = direction * 265;
        g.step(.1);
        final head = g.mergeRun.segmentX(g.ballX, 0);
        expect(head, g.ballX);
        expect(
          head - MergeRun.ballRadius,
          greaterThanOrEqualTo(MergeRun.platformLeft),
        );
        expect(
          head + MergeRun.ballRadius,
          lessThanOrEqualTo(MergeRun.platformRight),
        );
      }
    });
    test('food and gates pause, resume and reset together with $control', () {
      final g = BalanceGame()
        ..setControlMode(control)
        ..start(gameMode: GameMode.merge2048, levelNumber: 50);
      expect(g.board, isEmpty);
      expect(g.spiders, isEmpty);
      expect(g.specialHazards, isEmpty);
      expect(g.coins, isEmpty);
      g.mergeRun.gates.add(MergeGate(64, y: 100));
      g.setPaused(true);
      final foodY = g.mergeRun.orbs.first.y;
      final holeY = g.mergeRun.gates.first.y;
      g.step(.1);
      expect(g.mergeRun.orbs.first.y, foodY);
      expect(g.mergeRun.gates.first.y, holeY);
      g.setPaused(false);
      g.step(.1);
      expect(g.mergeRun.orbs.first.y, greaterThan(foodY));
      expect(g.mergeRun.gates.first.y, greaterThan(holeY));
      clearStream(g);
      g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, g.mergeRun.head * 2));
      g.step(1 / 120);
      expect(g.finished, true);
      expect(g.event, GameEvent.miss);
    });
  }
  testWidgets(
    'small phone keeps playing past 2048 and shows compact labels and loss',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false
        ..controlMode = ControlMode.analog;
      await tester.pumpWidget(ArcadeApp(profile: p));

      await selectWorld(tester, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await startWorld(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(MergeStatus), findsOneWidget);
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(
        tester.getRect(find.byType(MergeStatus)).top,
        greaterThanOrEqualTo(24),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('analog-left'))).bottom,
        lessThanOrEqualTo(544),
      );
      clearStream(g);
      g.mergeRun.segments
        ..clear()
        ..add(1024);
      g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, 1024));
      await tester.pump(const Duration(milliseconds: 30));
      expect(g.finished, false);
      expect(find.byType(MergeResult), findsNothing);
      expect(find.text('CONTINUE TO 4096'), findsNothing);
      expect(find.text('TOP 2k'), findsOneWidget);
      expect(find.text('MATCH 2k'), findsOneWidget);
      final elapsed = g.elapsed;
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.elapsed, greaterThan(elapsed));
      g.mergeRun.segments
        ..clear()
        ..addAll(fullSnake());
      g.mergeRun.gates
        ..clear()
        ..add(MergeGate(g.mergeRun.head, y: g.ballY));
      await tester.pump(const Duration(milliseconds: 30));
      expect(g.finished, true);
      expect(find.text('Gate not cleared.'), findsOneWidget);
      await tester.tap(find.text('PLAY AGAIN'));
      await tester.pump(const Duration(milliseconds: 30));
      clearStream(g);
      g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, g.mergeRun.head * 2));
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('Number too large.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
