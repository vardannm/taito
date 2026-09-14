import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'game_test.dart' show advance, placeAt;

void main() {
  test('pausing immediately after a fast swipe leaves no motor carry-over', () {
    final g = BalanceGame()..start();
    g.board.clear();
    g.grabPivot(0);
    g.dragPivot(0, -80);
    g.step(1 / 120);
    final left = g.left;
    g.setPaused(true);
    g.setPaused(false);
    g.step(1 / 120);
    expect(g.left, left);
  });
  test('small one-finger precision movements count as active steering', () {
    final g = BalanceGame()
      ..setControlMode(ControlMode.oneFinger)
      ..start(gameMode: GameMode.infinite);
    g.stallTime = 3.2;
    for (var i = 1; i <= 10; i++) {
      g.setControlPosition(i * .01);
    }
    expect(g.dangerActive, isFalse);
    g.setPaused(true);
    g.setControlPosition(.8);
    expect(g.controlPosition, .1);
  });
  testWidgets('small-phone settings select one finger and launch level 50', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Two-Finger Control'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(const ValueKey('control-oneFinger')));
    await tester.tap(find.byKey(const ValueKey('control-oneFinger')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(p.controlMode, ControlMode.oneFinger);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Make yourself at home.'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('CLASSIC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-50')),
      250,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -180),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('level-50')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(g.level, 50);
    expect(g.oneFinger, isTrue);
    expect(g.lives, 3);
    expect(find.textContaining('L50'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('one-finger lift waits at the target height rather than passing it', () {
    final g = BalanceGame()
      ..setControlMode(ControlMode.oneFinger)
      ..start();
    g.ballX = g.activeHole.x < 180 ? 300 : 60;
    g.board.removeWhere((h) => h.target != 1);
    advance(g, 8);
    expect(
      (g.left + g.right) / 2,
      closeTo(g.activeHole.y + BalanceGame.ballRadius, .001),
    );
    expect(g.canControl, isTrue);
  });
  test(
    'generated rows retain a continuous generous route at every difficulty',
    () {
      var earlyCount = 0, lateCount = 0;
      for (var seed = 0; seed < 40; seed++) {
        for (final progress in [0, 400, 900, 1600, 2500]) {
          final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
          g.cameraOffset = progress * 10.0;
          g.score = progress * 20;
          g.ensureInfiniteBoard();
          var reachable = [for (var x = 60; x <= 300; x += 4) x.toDouble()];
          for (var screenY = 620; screenY >= -120; screenY -= 8) {
            final y = screenY - g.cameraOffset;
            final holes = g.board.where((h) => (h.y - y).abs() < 25);
            final safe = [
              for (var x = 60; x <= 300; x += 4)
                if (holes.every(
                  (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) > 25 * 25,
                ))
                  x.toDouble(),
            ];
            reachable = safe
                .where((x) => reachable.any((old) => (old - x).abs() <= 8))
                .toList();
            expect(
              reachable,
              isNotEmpty,
              reason: 'Seed $seed height $progress',
            );
          }
          // Includes the staggered band just beyond the top edge.
          expect(g.board.length, lessThanOrEqualTo(48));
          if (progress == 0) earlyCount += g.board.length;
          if (progress == 1600) lateCount += g.board.length;
        }
      }
      expect(lateCount, greaterThan(earlyCount * 2));
    },
  );

  test('Infinite run seeds vary and difficulty grows smoothly with height', () {
    final signatures = <String>{};
    for (var seed = 0; seed < 20; seed++) {
      final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
      signatures.add(g.board.map((h) => '${h.x},${h.y}').join('/'));
      expect(g.board.length, inInclusiveRange(1, 6));
      final rows = g.board.map((h) => h.y).toSet().toList()..sort();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i] - rows[i - 1], greaterThan(12));
      }
      expect(g.specialHazards, isEmpty);
    }
    expect(signatures.length, 20);
    final g = BalanceGame()..start(gameMode: GameMode.infinite);
    var previous = g.ascentSpeed;
    for (var score = 1; score <= 2000; score++) {
      g.maxHeight = score * 10.0;
      expect(g.ascentSpeed, inInclusiveRange(previous, previous + .28));
      previous = g.ascentSpeed;
    }
    expect(previous, 216);
    final a = BalanceGame(seed: 17)..start(gameMode: GameMode.infinite);
    final b = BalanceGame(seed: 17)..start(gameMode: GameMode.infinite);
    expect(a.board.map((h) => h.x), b.board.map((h) => h.x));
    final initial = a.board.first.x;
    a.start(gameMode: GameMode.infinite);
    expect(a.board.first.x, isNot(initial));
  });

  test(
    'all 50 levels are distinct and all targets complete in both controls',
    () {
      final layouts = <String>{};
      for (var level = 1; level <= ClassicLevels.count; level++) {
        final board = ClassicLevels.build(level);
        layouts.add(board.map((h) => '${h.x},${h.y}').join('/'));
        expect(board.where((h) => h.target > 0).length, 10);
        for (final control in ControlMode.values) {
          final g = BalanceGame()
            ..setControlMode(control)
            ..start(levelNumber: level);
          for (var i = 1; i <= 10; i++) {
            placeAt(g, g.activeHole);
            advance(g, 1.5);
          }
          expect(g.won, isTrue, reason: 'Level $level / $control');
          expect(g.finished, isTrue);
          expect(g.completed, 10);
          expect(g.lives, 3);
          expect(g.score, greaterThan(0));
        }
        // Flood-fill actual layouts; every target needs a ball-width route.
        for (final target in board.where((h) => h.target > 0)) {
          final queue = <(int, int)>[(45, 129)], seen = <(int, int)>{(45, 129)};
          var reached = false;
          for (var head = 0; head < queue.length && !reached; head++) {
            final (x, y) = queue[head];
            if (math.pow(x * 4 - target.x, 2) + math.pow(y * 4 - target.y, 2) <
                100) {
              reached = true;
              break;
            }
            for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
              final n = (x + dx, y + dy);
              if (n.$1 < 8 ||
                  n.$1 > 82 ||
                  n.$2 < 8 ||
                  n.$2 > 129 ||
                  seen.contains(n))
                continue;
              if (board.any(
                (h) =>
                    h != target &&
                    math.pow(n.$1 * 4 - h.x, 2) + math.pow(n.$2 * 4 - h.y, 2) <
                        225,
              ))
                continue;
              seen.add(n);
              queue.add(n);
            }
          }
          expect(
            reached,
            isTrue,
            reason: 'Level $level target ${target.target}',
          );
        }
      }
      expect(layouts.length, ClassicLevels.count);
      expect(
        ClassicLevels.build(30).length,
        greaterThan(ClassicLevels.build(1).length + 15),
      );
    },
  );

  test(
    'touch follows in one tick, including release before the next frame',
    () {
      final g = BalanceGame()..start();
      g.board.clear();
      g.grabPivot(0);
      g.grabPivot(1);
      g.dragPivot(0, -180);
      g.dragPivot(1, -140);
      g.releasePivot(0);
      g.releasePivot(1);
      g.step(1 / 120);
      expect(g.left, 346);
      expect(g.right, 386);
      expect(g.pivotTargets, [null, null]);
      g.step(1 / 120);
      expect(g.left, 346);
      expect(g.right, 386);
    },
  );

  test('fast swipe hits the first trap even if a target is listed first', () {
    final g = BalanceGame()..start();
    g.board
      ..clear()
      ..addAll([const Hole(180, 350, target: 1), const Hole(180, 450)]);
    g.grabPivot(0);
    g.grabPivot(1);
    g.dragPivot(0, -220);
    g.dragPivot(1, -220);
    g.step(1 / 120);
    expect(g.lives, 2);
    expect(g.score, 0);
    expect(g.captureY, 450);
  });

  for (final mode in [GameMode.classic, GameMode.infinite]) {
    testWidgets('one-finger fast drag, limits, pause and switching in $mode', (
      tester,
    ) async {
      final g = BalanceGame()
        ..setControlMode(ControlMode.oneFinger)
        ..start(gameMode: mode);
      if (g.infinite) g.board.clear();
      final frame = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            height: 560,
            child: PivotBoard(game: g, frame: frame),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(PivotBoard));
      final view = BoardViewport(rect.size);
      final start = rect.topLeft + view.project(Offset(180, g.controlY));
      final finger = await tester.startGesture(start);
      await finger.moveBy(Offset(200 * view.scale, 0));
      g.step(1 / 120);
      expect(g.right - g.left, closeTo(140, .001));
      await finger.moveBy(Offset(-400 * view.scale, 0));
      g.step(1 / 120);
      expect(g.right - g.left, closeTo(-140, .001));
      g.setPaused(true);
      final left = g.left;
      await finger.moveBy(Offset(50, 0));
      g.step(.05);
      expect(g.left, left);
      g.setPaused(false);
      g.setControlMode(ControlMode.twoFinger);
      await finger.moveBy(Offset(50, 0));
      expect(g.pivotTargets, [null, null]);
      await finger.up();
      await tester.pumpWidget(const SizedBox());
      frame.dispose();
    });
  }
  test('control mode and selected Classic level persist', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final p = PlayerProfile();
    await p.load();
    expect(p.controlMode, ControlMode.twoFinger);
    p.controlMode = ControlMode.oneFinger;
    p.classicLevel = 26;
    await p.save();
    final q = PlayerProfile();
    await q.load();
    expect(q.controlMode, ControlMode.oneFinger);
    expect(q.classicLevel, 26);
  });
}
