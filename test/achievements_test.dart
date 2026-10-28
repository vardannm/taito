import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/achievements.dart';
import 'package:balance_arcade/achievement_sheet.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'locked rewards cannot pay; old records count and claims persist once',
    () async {
      final p = PlayerProfile(unlimitedCoins: false)..wallet = 42;
      expect(await p.claimAchievement(Achievement.distance1000), isFalse);
      expect(p.wallet, 42);
      p.infiniteBest = 1200;
      await p.save();
      final loaded = PlayerProfile(unlimitedCoins: false);
      await loaded.load();
      expect(loaded.achievementProgress(Achievement.distance2500), 1200);
      expect(loaded.achievementEarned(Achievement.distance1000), isTrue);
      final results = await Future.wait([
        loaded.claimAchievement(Achievement.distance1000),
        loaded.claimAchievement(Achievement.distance1000),
      ]);
      expect(results, [true, false]);
      expect(loaded.wallet, 142);
      loaded.selectBall(BallCosmetic.coral);
      await loaded.saveEconomy();
      final restarted = PlayerProfile(unlimitedCoins: false);
      await restarted.load();
      expect(restarted.achievementClaimed(Achievement.distance1000), isTrue);
      expect(
        await restarted.claimAchievement(Achievement.distance1000),
        isFalse,
      );
      expect(restarted.wallet, 142 - BallCosmetic.coral.cost);
    },
  );

  test('finished Infinite runs unlock achievements without counting twice', () {
    final p = PlayerProfile();
    final g = BalanceGame(seed: 1)..start(gameMode: GameMode.infinite);
    g.maxHeight = 10000;
    g.phase = GamePhase.over;
    p.recordResult(g);
    p.recordResult(g);
    expect(p.infiniteRuns, 1);
    expect(p.achievementEarned(Achievement.firstRun), isTrue);
    expect(p.achievementEarned(Achievement.distance1000), isTrue);
    expect(p.achievementEarned(Achievement.distance2500), isFalse);
  });

  test('Classic and Merge achievements use saved mode records', () async {
    final p = PlayerProfile();
    for (var level = 1; level <= 4; level++) {
      p.levelRecords[p.recordKey(level, ControlMode.oneFinger)] =
          const LevelRecord(starMask: 7);
    }
    p.mergeHighest = 128;
    await p.save();
    final loaded = PlayerProfile();
    await loaded.load();
    for (final a in [Achievement.stars12, Achievement.merge128]) {
      expect(loaded.achievementEarned(a), isTrue, reason: a.name);
    }
  });

  test('additional milestones use existing saved records', () async {
    expect(Achievement.values.length, 33);
    final p = PlayerProfile()
      ..infiniteBest = 5000
      ..infiniteBestScore = 1000000
      ..infiniteBestBosses = 6
      ..infiniteRuns = 100
      ..mergeHighest = 4096
      ..mergeRuns = 100;
    for (var level = 1; level <= 50; level++) {
      p.levelRecords[p.recordKey(level, ControlMode.oneFinger)] =
          const LevelRecord(starMask: 15);
    }
    p.dailyPrizes.claimed = 60;
    p.dailyPrizes.lastClaim = DateTime.utc(2026, 9, 30);
    await p.save();
    final loaded = PlayerProfile();
    await loaded.load();
    for (final achievement in Achievement.values.skip(8)) {
      expect(
        loaded.achievementEarned(achievement),
        true,
        reason: achievement.name,
      );
    }
  });
  test(
    'return visits survive missed days, restarts and duplicate claims',
    () async {
      final p = PlayerProfile(unlimitedCoins: false);
      final day = DateTime.utc(2026, 1, 1);
      for (final offset in [0, 3, 9]) {
        final date = day.add(Duration(days: offset));
        expect(await p.claimDailyPrize(now: date), isNotNull);
        expect(await p.claimDailyPrize(now: date), isNull);
      }
      final loaded = PlayerProfile(unlimitedCoins: false);
      await loaded.load();
      expect(loaded.achievementEarned(Achievement.visits3), true);
      expect(loaded.achievementProgress(Achievement.visits7), 3);
      expect(await loaded.claimDailyPrize(now: day), isNull);
      final wallet = loaded.wallet;
      expect(await loaded.claimAchievement(Achievement.visits3), true);
      expect(await loaded.claimAchievement(Achievement.visits3), false);
      expect(loaded.wallet, wallet + Achievement.visits3.coins);
      final restarted = PlayerProfile(unlimitedCoins: false);
      await restarted.load();
      expect(restarted.achievementClaimed(Achievement.visits3), true);
      expect(restarted.achievementProgress(Achievement.visits60), 3);
    },
  );

  testWidgets('opening achievements scrolls to the first reward to claim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ready = Achievement.values.last;
    final p = PlayerProfile();
    // Everything earlier is already claimed; only the last card is ready.
    switch (ready) {
      case Achievement.visits60:
        p.dailyPrizes.claimed = 60;
      default:
        fail('Update this test for the new last achievement: $ready');
    }
    p.replaceClaimedAchievements(
      Achievement.values.where((a) => a != ready && p.achievementEarned(a)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AchievementSheet(profile: p)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('claim-${ready.name}')).hitTestable(),
      findsOneWidget,
    );
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets(
      'achievement sheet fits a small phone at text scale $scale and claims',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = PlayerProfile()..infiniteRuns = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(body: AchievementSheet(profile: p)),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('claim-firstRun')).hitTestable(),
          200,
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('claim-firstRun')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(p.wallet, Achievement.firstRun.coins);
        expect(find.text('CLAIMED'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Part of the arcade'),
          400,
          maxScrolls: 60,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the menu button opens achievements; Modes does not list them', (
    tester,
  ) async {
    final p = PlayerProfile()..tutorialSeen = true;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.pump();
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ACHIEVEMENTS'), findsNothing);
    expect(find.text('GEAR SHOP'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Achievements').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AchievementSheet), findsOneWidget);
    expect(find.text('0 of 33 earned'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the big menu button opens achievements; Modes is in the corner',
    (tester) async {
      final p = PlayerProfile()..tutorialSeen = true;
      await tester.pumpWidget(ArcadeApp(profile: p));
      await tester.pump();
      expect(find.byTooltip('Modes'), findsOneWidget);
      expect(find.text('Arcade'), findsNothing);
      await tester.tap(find.text('Achievements'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AchievementSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('achievements and the arcade open full screen and swipe closed', (
    tester,
  ) async {
    final p = PlayerProfile()..tutorialSeen = true;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.pump();
    await tester.tap(find.text('Achievements'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AchievementSheet), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.dragFrom(const Offset(120, 420), const Offset(160, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AchievementSheet), findsNothing);
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your arcade'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your arcade'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('outlasting bosses counts toward the boss achievements', () {
    final game = BalanceGame(seed: 5)..start(gameMode: GameMode.infinite);
    game.boss = InfiniteBoss(kind: BossKind.novaPulsar);
    for (var i = 0; i < 29 * 120 && game.boss != null; i++) {
      game.survival.shield = 99;
      game.lives = 3;
      game.step(1 / 120);
    }
    expect(game.boss, isNull);
    expect(game.bossesCleared, 1);
    final p = PlayerProfile();
    game
      ..phase = GamePhase.over
      ..lives = 0;
    p.recordResult(game);
    expect(p.infiniteBestBosses, 1);
    expect(p.achievementEarned(Achievement.boss1), isTrue);
    expect(p.achievementProgress(Achievement.boss3), 1);
  });
}
