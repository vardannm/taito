import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/merge.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/merge_widgets.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'different numbers stack; matching neighbors chain and score each merge',
    () {
      final run = MergeRun(seed: 1);
      run.collect(4);
      expect(run.stack, [2, 4]);
      run.collect(4);
      expect(run.stack, [2, 8]);
      run.stack
        ..clear()
        ..addAll([8, 4, 2]);
      run.score = 0;
      run.collect(2);
      expect(run.stack, [16]);
      expect(run.lastChain, 3);
      expect(run.score, 28);
      expect(run.notice, contains('+28'));
    },
  );
  test('full stack permits rescue but rejects a mismatched seventh slot', () {
    final run = MergeRun();
    run.stack
      ..clear()
      ..addAll([64, 32, 16, 8, 4, 2]);
    run.collect(2);
    expect(run.stack, [128]);
    expect(run.overflow, false);
    run.stack
      ..clear()
      ..addAll([64, 32, 16, 8, 4, 2]);
    run.collect(8);
    expect(run.stack.length, 6);
    expect(run.overflow, true);
  });
  test('swept pickups resolve in path order even if stored backwards', () {
    final run = MergeRun()..orbs.clear();
    run.orbs.addAll([NumberOrb(180, 370, 4), NumberOrb(180, 470, 2)]);
    run.step(1 / 120, 180, 520, 180, 320);
    expect(run.stack, [8]);
    expect(run.score, 12);
    expect(run.orbs, isEmpty);
  });
  test(
    'spawning stays bounded and each new row contains the current match',
    () {
      final run = MergeRun(seed: 3)..orbs.clear();
      run.stack
        ..clear()
        ..add(64);
      for (var row = 0; row < 30; row++) {
        final old = Set<NumberOrb>.of(run.orbs);
        run.step(110 / run.speed + .001, -100, -100, -100, -100);
        final fresh = run.orbs.where((o) => !old.contains(o));
        expect(fresh.any((o) => o.value == 64), true);
        expect(run.orbs.length, lessThan(22));
        expect(run.overflow, false);
      }
    },
  );
  test('2048 win continues same run and records count it once', () async {
    final g = BalanceGame()..start(gameMode: GameMode.merge2048);
    final p = PlayerProfile();
    g.mergeRun.stack
      ..clear()
      ..add(1024);
    g.mergeRun.orbs
      ..clear()
      ..add(NumberOrb(g.ballX, g.ballY, 1024));
    g.step(1 / 120);
    expect(g.won, true);
    expect(g.finished, true);
    expect(g.earnedStarMask, 0);
    p.recordResult(g);
    g.continueMerge();
    expect(g.finished, false);
    expect(g.mergeRun.stack, [2048]);
    g.mergeRun.collect(2048);
    expect(g.mergeRun.won, false);
    g.mergeRun.stack
      ..clear()
      ..addAll([64, 32, 16, 8, 4, 2]);
    g.mergeRun.collect(8);
    g.step(1 / 120);
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
    expect(g.mergeRun.stack, [2]);
    expect(g.score, 0);
  });
  for (final control in ControlMode.values) {
    test('2048 respects pause and isolates hazards with $control', () {
      final g = BalanceGame()
        ..setControlMode(control)
        ..start(gameMode: GameMode.merge2048, levelNumber: 50);
      expect(g.board, isEmpty);
      expect(g.spiders, isEmpty);
      expect(g.coins, isEmpty);
      g.setPaused(true);
      final y = g.mergeRun.orbs.first.y;
      g.step(.1);
      expect(g.mergeRun.orbs.first.y, y);
      g.setPaused(false);
      g.step(.1);
      expect(g.mergeRun.orbs.first.y, greaterThan(y));
      expect(g.specialHazards, isEmpty);
    });
  }
  testWidgets(
    'small phone launches 2048 with analog controls and six safe slots',
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
      expect(find.byType(MergeTray), findsOneWidget);
      expect(find.text('MATCH 2'), findsOneWidget);
      final g = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(g.merging, true);
      expect(g.analog, true);
      final tray = tester.getRect(find.byType(MergeTray));
      final joystick = tester.getRect(
        find.byKey(const ValueKey('analog-left')),
      );
      expect(tray.top, greaterThanOrEqualTo(24));
      expect(joystick.bottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
      g.mergeRun.stack
        ..clear()
        ..add(1024);
      g.mergeRun.orbs
        ..clear()
        ..add(NumberOrb(g.ballX, g.ballY, 1024));
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('CONTINUE TO 4096'), findsOneWidget);
      await tester.ensureVisible(find.text('CONTINUE TO 4096'));
      await tester.tap(find.text('CONTINUE TO 4096'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(g.mergeRun.continued, true);
      expect(g.finished, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
