import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/mastery_widgets.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'game_test.dart' show advance;

void finish(
  BalanceGame g, {
  bool won = true,
  int misses = 0,
  double? time,
  int score = 1500,
}) {
  g.won = won;
  g.phase = GamePhase.over;
  g.misses = misses;
  g.elapsed = time ?? g.targetTime;
  g.score = score;
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'stars require completion, track independent goals, and merge across runs',
    () {
      final p = PlayerProfile()..controlMode = ControlMode.twoFinger;
      final g = BalanceGame()..start();
      finish(g, won: false);
      expect(g.earnedStarMask, 0);
      p.recordResult(g);
      g.start();
      finish(g, misses: 1);
      expect(g.earnedStarMask, 5);
      p.recordResult(g);
      g.start();
      finish(g, time: g.targetTime + 1);
      expect(g.earnedStarMask, 3);
      p.recordResult(g);
      expect(p.levelRecord(1).starMask, 7);
      expect(p.levelRecord(1).attempts, 3);
      expect(p.totalStars, 3);
    },
  );
  test(
    'records are idempotent per run, control-specific, and never lose a best',
    () {
      final p = PlayerProfile()..controlMode = ControlMode.twoFinger;
      final g = BalanceGame()..start();
      finish(g, time: 100, score: 2000);
      p.recordResult(g);
      p.recordResult(g);
      expect(p.runs, 1);
      g.start();
      finish(g, time: 130, score: 1000);
      p.recordResult(g);
      expect(p.levelRecord(1).bestScore, 2000);
      expect(p.levelRecord(1).bestTime, 100);
      g.setControlMode(ControlMode.oneFinger);
      g.start();
      finish(g, time: 160);
      p.recordResult(g);
      expect(p.levelRecord(1, ControlMode.oneFinger).bestTime, 160);
      expect(p.levelRecord(1, ControlMode.twoFinger).bestTime, 100);
      expect(p.totalStars, 3);
      g.start(gameMode: GameMode.practice);
      finish(g);
      p.recordResult(g);
      expect(p.runs, 3);
    },
  );
  test(
    'records and earned cabinet persist; locked styles cannot be equipped',
    () async {
      final p = PlayerProfile()..controlMode = ControlMode.twoFinger;
      final g = BalanceGame()..start();
      expect(p.selectCabinet(CabinetStyle.jade), isFalse);
      finish(g);
      p.recordResult(g);
      expect(p.selectCabinet(CabinetStyle.jade), isTrue);
      expect(p.selectCabinet(CabinetStyle.ember), isFalse);
      g.start(
        gameMode: GameMode.daily,
        challengeDate: DateTime.utc(2026, 9, 9),
      );
      finish(g);
      p.recordResult(g);
      await p.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.cabinet, CabinetStyle.jade);
      expect(restored.levelRecord(1).starMask, 7);
      expect(restored.dailyRecord('2026-09-09').attempts, 1);
      expect(restored.best, 1500);
    },
  );
  test(
    'daily board uses UTC day, stable integer seed, and separate local records',
    () {
      final date = DateTime.parse('2026-09-10T01:30:00+04:00');
      final a = BalanceGame()
        ..start(gameMode: GameMode.daily, challengeDate: date);
      final b = BalanceGame()
        ..start(
          gameMode: GameMode.daily,
          challengeDate: DateTime.utc(2026, 9, 9, 23),
        );
      String layout(BalanceGame g) =>
          g.board.map((h) => '${h.x}/${h.y}').join(',');
      expect(a.dailyKey, '2026-09-09');
      expect(layout(a), layout(b));
      b.start(
        gameMode: GameMode.daily,
        challengeDate: DateTime.utc(2026, 9, 10),
      );
      expect(layout(a), isNot(layout(b)));
      expect(a.spiders, isEmpty);
      expect(a.finale, isFalse);
      final p = PlayerProfile()..controlMode = a.controlMode;
      finish(a);
      p.recordResult(a);
      expect(p.dailyRecord('2026-09-09').stars, 3);
      expect(p.runs, 0);
      expect(p.best, 0);
      expect(p.totalStars, 0);
      expect(p.dailyRecord('2026-09-10').attempts, 0);
      final expectedState = ((20260909 % 2147483646 + 1) * 48271) % 2147483647;
      expect(
        DailyRandom(20260909).nextDouble(),
        (expectedState - 1) / 2147483646,
      );
    },
  );
  test('a full year of daily seeds always has ten spaced targets', () {
    for (var d = 0; d < 366; d++) {
      final date = DateTime.utc(2026, 1, 1).add(Duration(days: d));
      final board = ClassicLevels.build(
        15,
        dailySeed: DailyChallenge.seed(date),
      );
      expect(
        board.where((h) => h.target > 0).map((h) => h.target),
        orderedEquals(List.generate(10, (i) => i + 1)),
        reason: DailyChallenge.key(date),
      );
      for (var i = 0; i < board.length; i++) {
        for (var j = i + 1; j < board.length; j++) {
          expect(
            math.sqrt(
              math.pow(board[i].x - board[j].x, 2) +
                  math.pow(board[i].y - board[j].y, 2),
            ),
            greaterThan(30),
          );
        }
      }
    }
  });
  test('daily records remain bounded to 32 days across all controls', () {
    final p = PlayerProfile(), g = BalanceGame();
    for (var d = 0; d < 45; d++) {
      for (final control in ControlMode.values) {
        g.setControlMode(control);
        g.start(
          gameMode: GameMode.daily,
          challengeDate: DateTime.utc(2026, 1, 1).add(Duration(days: d)),
        );
        finish(g);
        p.recordResult(g);
      }
    }
    expect(p.dailyRecords.length, 32 * ControlMode.values.length);
    expect(p.dailyRecord('2026-01-01').attempts, 0);
    expect(p.dailyRecord('2026-02-14').attempts, 1);
  });
  test(
    'coins sit near traps without overlapping holes or spider territories',
    () {
      for (var level = 1; level <= 50; level++) {
        final g = BalanceGame()..start(levelNumber: level);
        expect(g.coins.length, inInclusiveRange(2, 3), reason: 'Level $level');
        for (final c in g.coins) {
          expect(
            g.board.any(
              (h) =>
                  h.target == 0 &&
                  math.pow(c.x - h.x, 2) + math.pow(c.y - h.y, 2) <= 33 * 33,
            ),
            isTrue,
          );
          for (final h in g.board) {
            expect(
              math.sqrt(math.pow(c.x - h.x, 2) + math.pow(c.y - h.y, 2)),
              greaterThanOrEqualTo(h.target > 0 ? 34 : 25),
            );
          }
          for (final spider in g.spiders) {
            expect(
              math.sqrt(
                math.pow(c.x - spider.homeX, 2) +
                    math.pow(c.y - spider.homeY, 2),
              ),
              greaterThanOrEqualTo(spider.zoneRadius + 12),
            );
          }
        }
      }
    },
  );
  test(
    'fast swipes collect a coin once, retain controls, and cannot farm a reset',
    () {
      final g = BalanceGame()..start();
      g.board.clear();
      g.coins
        ..clear()
        ..add(BrassCoin(180, 450));
      g.left = g.right = 500;
      g.grabPivot(0);
      g.grabPivot(1);
      g.dragPivot(0, -100);
      g.dragPivot(1, -100);
      g.step(1 / 120);
      expect(g.coinsCollected, 1);
      expect(g.score, 250);
      expect(g.event, GameEvent.coin);
      expect(g.pivotTargets.every((p) => p != null), isTrue);
      g.resetBall();
      g.left = g.right = 457;
      g.step(1 / 120);
      expect(g.coinsCollected, 1);
      expect(g.score, 250);
      g.start();
      expect(g.coins.every((c) => !c.collected), isTrue);
    },
  );
  test('a fatal hole stops collection behind it on the same swipe', () {
    final g = BalanceGame()..start();
    g.board
      ..clear()
      ..add(const Hole(180, 480));
    g.coins
      ..clear()
      ..add(BrassCoin(180, 450));
    g.left = g.right = 500;
    g.grabPivot(0);
    g.grabPivot(1);
    g.dragPivot(0, -100);
    g.dragPivot(1, -100);
    g.step(1 / 120);
    expect(g.phase, GamePhase.sinking);
    expect(g.coinsCollected, 0);
    expect(g.score, 0);
  });
  test('a live finale laser stops coin collection on a fast crossing', () {
    final g = BalanceGame()..start(levelNumber: 10);
    g.board
      ..clear()
      ..add(const Hole(300, 100, target: 1));
    g.coins
      ..clear()
      ..add(BrassCoin(220, 393));
    g.specialHazards.add(
      SpecialHazard(HazardKind.laser, x: 180, y: 0, warningSeconds: 0),
    );
    g.left = g.right = 400;
    g.ballX = 160;
    g.velocity = 265;
    // The swept entry reaches the beam before the coin on subsequent ticks.
    advance(g, .3);
    expect(g.lives, 2);
    expect(g.coinsCollected, 0);
  });
  test('pause and ball return animations are excluded from the star timer', () {
    final g = BalanceGame()..start();
    g.setPaused(true);
    advance(g, 5);
    expect(g.elapsed, 0);
    g.setPaused(false);
    g.phase = GamePhase.returning;
    advance(g, .5);
    expect(g.elapsed, 0);
    final two = g.targetTime;
    g.setControlMode(ControlMode.oneFinger);
    g.start();
    expect(g.targetTime, greaterThan(two + 40));
  });
  test(
    'finale laser warns, pauses, takes one life, and resets between attempts',
    () {
      final g = BalanceGame()..start(levelNumber: 10);
      g.board
        ..clear()
        ..add(const Hole(300, 450, target: 1));
      g.coins.clear();
      g.ballX = 30;
      advance(g, 3.1);
      expect(g.specialHazards.length, 1);
      final h = g.specialHazards.first;
      expect(h.warning, isTrue);
      final age = h.age;
      g.setPaused(true);
      advance(g, 4);
      expect(h.age, age);
      g.setPaused(false);
      g.ballX = h.x;
      g.left = g.right = 400;
      advance(g, 1);
      expect(g.lives, 3);
      advance(g, 1.5);
      expect(g.lives, 2);
      expect(g.phase, GamePhase.sinking);
      advance(g, 1.5);
      expect(g.specialHazards, isEmpty);
      expect(g.phase, GamePhase.playing);
      g.start(gameMode: GameMode.daily);
      expect(g.finale, isFalse);
      expect(g.specialHazards, isEmpty);
    },
  );
  test(
    'keeper finales have larger spiders and a route outside their zones',
    () {
      for (final level in [40, 50]) {
        final g = BalanceGame()..start(levelNumber: level);
        expect(g.spiders.first.bodyRadius, 11);
        expect(ClassicLevels.hasSafeRoutes(g.board, g.spiders), isTrue);
      }
    },
  );
  test('Infinite rhythm changes pressure without reducing ascent speed', () {
    expect(sectionAt(179), InfiniteSection.rush);
    expect(sectionAt(180), InfiniteSection.breath);
    expect(sectionAt(2490), InfiniteSection.encounter);
    expect(sectionAt(2520), InfiniteSection.rush);
    expect(
      InfiniteSection.breath.densityFactor,
      lessThan(InfiniteSection.rush.densityFactor),
    );
    final g = BalanceGame()..start(gameMode: GameMode.infinite);
    g.maxHeight = 900;
    final before = g.ascentSpeed;
    g.maxHeight = 1200;
    expect(g.ascentSpeed, greaterThan(before));
    g.maxHeight = 2850;
    g.ballX = 332;
    g.board.clear();
    g.step(1 / 120);
    expect(g.section, InfiniteSection.breath);
    expect(g.specialHazards, isEmpty);
  });
  test('cabinet changes leave simulation identical', () {
    final a = BalanceGame()..start(gameMode: GameMode.practice);
    final b = BalanceGame()
      ..cabinet = CabinetStyle.ember
      ..start(gameMode: GameMode.practice);
    a.leftInput = b.leftInput = -.3;
    a.rightInput = b.rightInput = -.5;
    advance(a, 2);
    advance(b, 2);
    expect(a.ballX, b.ballX);
    expect(a.ballY, b.ballY);
    expect(a.score, b.score);
  });
  testWidgets('phone home launches daily and retains the date on retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('DAILY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('PLAY DAILY'));
    await tester.tap(find.text('PLAY DAILY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    final date = g.dailyKey;
    expect(g.daily, isTrue);
    finish(g, won: false);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.ensureVisible(find.text('ONE MORE RUN'));
    await tester.tap(find.text('ONE MORE RUN'));
    await tester.pump();
    expect(g.dailyKey, date);
    expect(g.finished, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cabinet and result fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()..controlMode = ControlMode.twoFinger;
    final g = BalanceGame()..start();
    finish(g);
    p.recordResult(g);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: CabinetPicker(profile: p, onSelected: p.selectCabinet),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cabinet-ember')),
      150,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MasteryResult(
              game: g,
              record: p.levelRecord(1),
              unlocks: [CabinetStyle.jade],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Jade garden unlocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
