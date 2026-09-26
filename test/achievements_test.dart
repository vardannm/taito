import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/achievements.dart';
import 'package:balance_arcade/achievement_sheet.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/game.dart';
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

  test('Classic, Maze and Merge achievements use saved mode records', () async {
    final p = PlayerProfile();
    for (var level = 1; level <= 4; level++) {
      p.levelRecords[p.recordKey(level, ControlMode.oneFinger)] =
          const LevelRecord(starMask: 7);
    }
    p.mazeBestTimes[p.recordKey(1, ControlMode.oneFinger)] = 45;
    p.mergeHighest = 128;
    await p.save();
    final loaded = PlayerProfile();
    await loaded.load();
    for (final a in [
      Achievement.stars12,
      Achievement.mazeClear,
      Achievement.merge128,
    ]) {
      expect(loaded.achievementEarned(a), isTrue, reason: a.name);
    }
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
        await tester.scrollUntilVisible(find.text('Power of two'), 300);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Modes opens the achievements screen', (tester) async {
    final p = PlayerProfile()..tutorialSeen = true;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await tester.pump();
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('ACHIEVEMENTS'));
    await tester.tap(find.text('ACHIEVEMENTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AchievementSheet), findsOneWidget);
    expect(find.text('0 of 9 earned'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
