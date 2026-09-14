import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/merge.dart';
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

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'requested centered 2 16 32 8 4 layout cascades to 64 with another 2',
    () {
      final run = emptyRun()..segments.insert(0, 32);
      for (final value in [16, 8, 4]) {
        run.collect(value);
        expect(run.head, 32);
        expect(run.segmentX(180, 0), 180);
      }
      final order = List.generate(run.segments.length, (i) => i)
        ..sort((a, b) => run.segmentSlot(a).compareTo(run.segmentSlot(b)));
      expect(order.map((i) => run.segments[i]), [2, 16, 32, 8, 4]);
      expect(run.leftSpan, run.rightSpan);
      run.collect(2);
      expect(run.segments, [64]);
      expect(run.lastChain, 5);
      expect(run.lastMergeScore, 124);
      expect(run.score, 124);
      expect(run.ended, false);
    },
  );
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
  test(
    '4 keeps the middle and a faint 2 attaches left before merging to 8',
    () {
      final run = emptyRun()..collect(2);
      run.collect(2);
      expect(run.segments, [4, 2]);
      expect(run.segmentSlot(0), 0);
      expect(run.segmentSlot(1), -1);
      run.collect(2);
      expect(run.segments, [8]);
      expect(run.lastMergeScore, 12);
    },
  );
  test(
    'every length grows on both sides with the biggest in a middle slot',
    () {
      final run = emptyRun();
      for (var count = 1; count <= MergeRun.maxSegments; count++) {
        run.segments
          ..clear()
          ..addAll(List.generate(count, (i) => 1 << (count - i)));
        final slots = List.generate(count, run.segmentSlot)..sort();
        expect(slots.toSet().length, count);
        expect(slots.last - slots.first + 1, count);
        expect(
          (run.leftSpan - run.rightSpan).abs(),
          lessThanOrEqualTo(MergeRun.segmentSpacing),
        );
        expect(run.segmentSlot(0), 0);
        expect(run.head, 1 << count);
        expect(run.length, lessThanOrEqualTo(MergeRun.platformWidth));
        expect(run.minHeadX, lessThanOrEqualTo(run.maxHeadX));
      }
    },
  );
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
  test(
    'only the middle ball collects; ghosts pass through dangerous numbers',
    () {
      final g = BalanceGame()..start(gameMode: GameMode.merge2048);
      clearStream(g);
      g.mergeRun.segments
        ..clear()
        ..addAll([16, 8, 4, 2]);
      final ghostX = g.mergeRun.segmentX(g.ballX, 3);
      g.mergeRun.orbs.add(NumberOrb(ghostX, g.ballY, 16));

      g.step(1 / 120);
      expect(g.mergeRun.segments, [16, 8, 4, 2]);
      expect(g.mergeRun.orbs.length, 1);
      expect(g.finished, false);
      clearStream(g);
      g.mergeRun.orbs.add(NumberOrb(g.ballX, g.ballY, 2));
      g.step(1 / 120);
      expect(g.mergeRun.segments, [32]);
    },
  );
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
      run.segments[0] = 512;
      for (final scoreAt in [400, 800, 1200]) {
        expect(run.gates.single.scoreAt, scoreAt);
        run.gates.single.y = 500;
        run.step(.01, 180, 500, 180, 500);
        for (var i = 0; i < 13; i++) run.step(.1, 180, 500, 180, 500);
      }
      expect(run.gatesPassed, 3);
      expect(run.gates, isEmpty);
      expect(run.nextGateScore, 1600);
      expect(MergeRun.gateValueAt(16400), 4096);
      expect(MergeRun.gateValueAt(4398046511104), 1099511627776);
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
      for (final direction in [-1, 1]) {
        g.ballX = direction < 0 ? g.mergeRun.minHeadX : g.mergeRun.maxHeadX;
        g.velocity = direction * 265;
        g.step(.1);
        for (var i = 0; i < g.mergeRun.segments.length; i++) {
          final x = g.mergeRun.segmentX(g.ballX, i);
          expect(
            x - MergeRun.ballRadius,
            greaterThanOrEqualTo(MergeRun.platformLeft),
          );
          expect(
            x + MergeRun.ballRadius,
            lessThanOrEqualTo(MergeRun.platformRight),
          );
        }
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
      await tester.ensureVisible(find.text('2048  /  MERGE'));
      await tester.tap(find.text('2048  /  MERGE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('PLAY 2048'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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
