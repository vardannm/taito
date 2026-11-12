import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('best score unlocks a smooth linear bonus with a 2.5x cap', () {
    const cases = <int, double>{
      -1: 1,
      0: 1,
      299999: 1,
      300000: 1,
      300001: 1 + 1 / 600000,
      315000: 1.025,
      330000: 1.05,
      600000: 1.5,
      1000000: 13 / 6,
      1200000: 2.5,
      2000000: 2.5,
      1 << 30: 2.5,
    };
    for (final entry in cases.entries) {
      expect(
        InfiniteTuning.startingSpeedMultiplier(entry.key),
        closeTo(entry.value, 1e-10),
      );
      expect(
        InfiniteTuning.startingPace(entry.key),
        closeTo(entry.value, 1e-10),
      );
    }
  });

  test('pace rewards the opening then normal progression catches up', () {
    final boosted = InfiniteProgress(startingPace: 2.5);
    final normal = InfiniteProgress();
    expect(boosted.points, 0);
    expect(boosted.combo, 1);
    expect(boosted.paceAt(0), 2.5);
    expect(boosted.paceAt(899), 2.5);
    expect(boosted.paceAt(900), normal.paceAt(900));
    expect(boosted.paceAt(1200), normal.paceAt(1200));
    expect(boosted.paceAt(10000), 5);
    boosted.step(1, 100);
    normal.step(1, 100);
    expect(boosted.points, 250);
    expect(boosted.points, greaterThan(normal.points));
  });

  test(
    'speed eases after input, freezes on pause and keeps the normal ceiling',
    () {
      final profile = PlayerProfile()..infiniteBestScore = 1000000;
      final game = BalanceGame(seed: 7);
      profile.applyInfiniteStart(game);
      game.start(gameMode: GameMode.infinite, waitForInput: true);
      final opening = game.ascentSpeed;
      final target = InfiniteTuning.startSpeed * 13 / 6;
      expect(opening, lessThan(target));
      game.step(.1);
      expect(game.elapsed, 0);
      expect(game.cameraOffset, 0);
      expect(game.ascentSpeed, opening);
      game.beginInput();
      for (var i = 0; i < 150; i++) {
        game.step(1 / 120);
      }
      expect(
        game.ascentSpeed,
        closeTo(InfiniteTuning.startSpeed * 19 / 12, .001),
      );
      final elapsed = game.elapsed, speed = game.ascentSpeed;
      game.setPaused(true);
      game.step(.1);
      expect(game.elapsed, elapsed);
      expect(game.ascentSpeed, speed);
      game.setPaused(false);
      for (var i = 0; i < 151; i++) {
        game.step(1 / 120);
      }
      expect(game.ascentSpeed, closeTo(target, .001));
      expect(game.score, greaterThan(0));
      expect(game.score, lessThan(1000));
      final normal = BalanceGame()..start(gameMode: GameMode.infinite);
      for (final height in [18000.0, 24000.0, 100000.0]) {
        game.maxHeight = normal.maxHeight = height;
        expect(game.ascentSpeed, normal.ascentSpeed);
        expect(game.pace, normal.pace);
      }
    },
  );

  test(
    'uses score instead of metres and changes the bonus only on restart',
    () {
      final profile = PlayerProfile()
        ..infiniteBest = 2000000
        ..infiniteBestScore = 300000;
      final game = BalanceGame();
      profile.applyInfiniteStart(game);
      game.start(gameMode: GameMode.infinite);
      game.elapsed = 3;
      expect(game.ascentSpeed, InfiniteTuning.startSpeed);
      profile.infiniteBestScore = 600000;
      profile.applyInfiniteStart(game);
      expect(game.ascentSpeed, InfiniteTuning.startSpeed);
      expect(game.pace, 1);
      game.start(gameMode: GameMode.infinite);
      game.elapsed = 3;
      expect(game.ascentSpeed, InfiniteTuning.startSpeed * 1.5);
      expect(game.pace, 1.5);
      game.start(gameMode: GameMode.classic);
      expect(game.survival.startingPace, 1);
      expect(game.ascentSpeed, InfiniteTuning.startSpeed);
    },
  );

  test('tutorials preserve the gentle opening', () {
    final profile = PlayerProfile()..infiniteBestScore = 2000000;
    final game = BalanceGame();
    profile.applyInfiniteStart(game, tutorial: true);
    game.start(gameMode: GameMode.infinite);
    game.elapsed = 3;
    expect(game.ascentSpeed, InfiniteTuning.startSpeed);
    expect(game.pace, 1);
  });

  test('one lucky run on a fresh install does not speed the opening', () async {
    final profile = PlayerProfile();
    await profile.load();
    profile.recordInfinitePace(1200000);
    profile.infiniteBestScore = 1200000;
    expect(profile.infiniteStartSpeed, 1);
    profile.recordInfinitePace(1200000);
    expect(profile.infiniteStartSpeed, 1);
    // The third run at that score makes it repeatable: one small step only.
    profile.recordInfinitePace(1200000);
    expect(profile.infiniteStartSpeed, closeTo(1.05, 1e-10));
    profile.recordInfinitePace(1200000);
    expect(profile.infiniteStartSpeed, closeTo(1.1, 1e-10));
  });

  test('repeated early falls step the opening down', () {
    final profile = PlayerProfile()..infiniteBestScore = 600000;
    expect(profile.infiniteStartSpeed, closeTo(1.5, 1e-10));
    profile.recordInfinitePace(10000);
    profile.recordInfinitePace(10000);
    expect(profile.infiniteStartSpeed, closeTo(1.5, 1e-10));
    profile.recordInfinitePace(10000);
    expect(profile.infiniteStartSpeed, closeTo(1.45, 1e-10));
  });

  test('upgrading players keep their opening until ten new runs', () {
    final profile = PlayerProfile()..infiniteBestScore = 600000;
    for (var i = 0; i < 9; i++) {
      profile.recordInfinitePace(400000);
      expect(profile.infiniteStartSpeed, closeTo(1.5, 1e-10));
    }
    // Ten runs around 400,000 now describe the player: ease toward 1.1x.
    profile.recordInfinitePace(400000);
    expect(profile.infiniteStartSpeed, closeTo(1.45, 1e-10));
    for (var i = 0; i < 20; i++) {
      profile.recordInfinitePace(400000);
    }
    expect(
      profile.infiniteStartSpeed,
      closeTo(InfiniteTuning.startingSpeedMultiplier(400000), 1e-10),
    );
  });

  test('hidden pacing survives saving and loading', () async {
    final profile = PlayerProfile();
    await profile.load();
    for (var i = 0; i < 4; i++) {
      profile.recordInfinitePace(900000);
    }
    await profile.save();
    final restored = PlayerProfile();
    await restored.load();
    expect(restored.recentInfiniteScores, profile.recentInfiniteScores);
    expect(restored.infiniteStartSpeed, profile.infiniteStartSpeed);
  });

  testWidgets('settings no longer show a faster start switch', (tester) async {
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false
      ..infiniteBestScore = 1000000;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    await tester.pump();
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(game.survival.startingPace, closeTo(13 / 6, 1e-10));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('infinite-fast-start')), findsNothing);
    expect(find.text('Faster start'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
