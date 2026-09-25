import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/spiders.dart';
import 'game_test.dart' show placeAt, advance;

void main() {
  test(
    'boards after the introductory level scatter targets and remain deterministic',
    () {
      for (var n = 2; n <= ClassicLevels.count; n++) {
        final a = ClassicLevels.build(n), b = ClassicLevels.build(n);
        final targets = a.where((h) => h.target > 0).toList();
        expect(targets.length, 10);
        expect(a.map((h) => '${h.x}/${h.y}'), b.map((h) => '${h.x}/${h.y}'));
        expect(
          targets.map((h) => h.x).reduce(math.max) -
              targets.map((h) => h.x).reduce(math.min),
          greaterThan(150),
        );
        var up = 0, down = 0;
        for (var i = 1; i < targets.length; i++) {
          if (targets[i].y > targets[i - 1].y) {
            down++;
          } else {
            up++;
          }
          expect(
            (targets[i].x - targets[i - 1].x).abs(),
            greaterThanOrEqualTo(75),
          );
        }
        expect(up, greaterThanOrEqualTo(2));
        expect(down, greaterThanOrEqualTo(2));
      }
    },
  );
  test(
    'all twenty spider levels have safe marked territories and clear targets',
    () {
      for (var level = 31; level <= 50; level++) {
        final board = ClassicLevels.build(level),
            spiders = ClassicLevels.definition(
              level,
            ).spiders.map((s) => s.create()).toList();
        expect(
          spiders.length,
          level < 36
              ? 1
              : level < 43
              ? 2
              : 3,
          reason: 'Level $level',
        );
        expect(ClassicLevels.hasSafeRoutes(board, spiders), isTrue);
        for (final s in spiders) {
          for (final h in board.where((h) => h.target > 0)) {
            expect(
              math.sqrt(
                math.pow(s.homeX - h.x, 2) + math.pow(s.homeY - h.y, 2),
              ),
              greaterThanOrEqualTo(s.zoneRadius + 24),
            );
          }
        }
      }
      expect(ClassicLevels.definition(30).spiders, isEmpty);
    },
  );
  test(
    'slow patrol stays in territory, swept entry triggers pursuit, then contact kills',
    () {
      final s = BoardSpider(180, 250, 40);
      final startX = s.x, startY = s.y;
      for (var i = 0; i < 120; i++) {
        expect(s.step(1 / 120, 40, 500, 40, 500), isFalse);
      }
      expect(s.chasing, isFalse);
      expect(
        math.sqrt(math.pow(s.x - startX, 2) + math.pow(s.y - startY, 2)),
        inInclusiveRange(5, 10),
      );
      expect(s.step(1 / 120, 80, 290, 280, 290), isFalse);
      expect(s.chasing, isTrue);
      var eaten = false;
      for (var i = 0; i < 360 && !eaten; i++) {
        eaten = s.step(1 / 120, 280, 290, 280, 290);
      }
      expect(eaten, isTrue);
      s.reset();
      expect(s.chasing, isFalse);
      expect(s.time, 0);
    },
  );
  test(
    'spider contact ends run instantly once; pause, capture, replay and other modes reset it',
    () {
      final g = BalanceGame()..start(levelNumber: 31);
      final s = g.spiders.first;
      g.setPaused(true);
      advance(g, 2);
      expect(s.time, 0);
      g.setPaused(false);
      s.chasing = true;
      placeAt(g, g.activeHole);
      advance(g, 1.5);
      expect(g.spiders.every((s) => !s.chasing), isTrue);
      final score = g.score;
      g.spiders
        ..clear()
        ..add(BoardSpider(g.ballX, g.ballY, 40));
      g.step(1 / 120);
      expect(g.finished, isTrue);
      expect(g.lives, 0);
      expect(g.ballScale, 0);
      expect(g.score, score);
      expect(g.caughtBySpider, isTrue);
      final misses = g.misses;
      advance(g, 2);
      expect(g.misses, misses);
      g.start(levelNumber: 31);
      expect(g.caughtBySpider, isFalse);
      expect(g.spiders.length, 1);
      g.start(gameMode: GameMode.infinite, levelNumber: 50);
      expect(g.spiders, isEmpty);
      g.start(gameMode: GameMode.practice, levelNumber: 50);
      expect(g.spiders, isEmpty);
    },
  );
  test('fast crossing cannot skip the spider body', () {
    final s = BoardSpider(180, 250, 40);
    expect(s.step(1 / 120, 100, 250, 260, 250), isTrue);
  });
  for (final width in [320.0, 430.0, 800.0]) {
    testWidgets('level grid reaches 50 at width $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: LevelPicker(
                selected: 31,
                totalStars: 98,
                onSelected: (n) => chosen = n,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SliverGrid), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('level-50')),
        300,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 35,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('level-50'))),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('level-50')));
      expect(chosen, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
