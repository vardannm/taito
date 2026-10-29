import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/daily_prize_sheet.dart';
import 'package:balance_arcade/daily_prizes.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  for (final platform in [false, true]) {
    testWidgets(
      'day five claim choices stay separate with large text: $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final p = PlayerProfile();
        p.dailyPrizes.claimed = 4;
        p.dailyPrizes.lastClaim = DateTime.now().toUtc().subtract(
          const Duration(days: 1),
        );
        final ballPrize = p.prizeBall!, platformPrize = p.prizePlatform!;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DailyPrizeSheet(profile: p)),
          ),
        );
        final ball = find.byKey(const ValueKey('daily-claim-ball'));
        final rail = find.byKey(const ValueKey('daily-claim-platform'));
        await tester.ensureVisible(rail);
        await tester.pump();
        expect(
          tester.getRect(rail).top - tester.getRect(ball).bottom,
          greaterThanOrEqualTo(16),
        );
        for (final button in [ball, rail]) {
          final text = find.descendant(of: button, matching: find.byType(Text));
          expect(
            tester.getRect(button).contains(tester.getRect(text).topLeft),
            isTrue,
          );
          expect(
            tester.getRect(button).contains(tester.getRect(text).bottomRight),
            isTrue,
          );
        }
        await tester.ensureVisible(platform ? rail : ball);
        await tester.tap(platform ? rail : ball);
        await tester.pumpAndSettle();
        expect(
          platform
              ? p.ownedPlatforms.contains(platformPrize)
              : p.ownedBalls.contains(ballPrize),
          isTrue,
        );
        expect(find.text('CLAIMED TODAY'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'claims survive restart, reject repeated taps and clock rollback',
    () async {
      final p = PlayerProfile();
      final date = DateTime.utc(2026, 9, 25, 23, 59);
      final claims = await Future.wait([
        p.claimDailyPrize(now: date),
        p.claimDailyPrize(now: date),
      ]);
      expect(claims, ['10 coins', null]);
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.wallet, 10);
      expect(await restored.claimDailyPrize(now: date), isNull);
      expect(
        await restored.claimDailyPrize(
          now: date.subtract(const Duration(days: 1)),
        ),
        isNull,
      );
      expect(
        await restored.claimDailyPrize(
          now: date.add(const Duration(minutes: 1)),
        ),
        '15 coins',
      );
      expect(restored.wallet, 25);
    },
  );

  test(
    'daily count continues past day five and keeps progress across missed days',
    () async {
      for (final platform in [false, true]) {
        final p = PlayerProfile();
        for (var i = 0; i < 4; i++) {
          await p.claimDailyPrize(now: DateTime.utc(2026, 9, 1 + i * 2));
        }
        expect(p.wallet, 70);
        await p.claimDailyPrize(
          now: DateTime.utc(2026, 9, 10),
          platform: platform,
        );
        expect(
          platform
              ? p.ownedPlatforms.contains(PlatformStyle.copper)
              : p.ownedBalls.contains(BallCosmetic.coral),
          isTrue,
        );
        expect(p.selectedBall, BallCosmetic.steel);
        expect(p.selectedPlatform, PlatformStyle.classic);
        expect(p.dailyPrizes.displayedDay(DateTime.utc(2026, 9, 10)), 5);
        expect(p.dailyPrizes.nextDay, 6);
        expect(p.dailyPrizes.displayedDay(DateTime.utc(2026, 9, 11)), 6);
        expect(
          await p.claimDailyPrize(now: DateTime.utc(2026, 9, 11)),
          '10 coins',
        );
        expect(p.dailyPrizes.displayedDay(DateTime.utc(2026, 9, 11)), 6);
        expect(p.dailyPrizes.nextDay, 7);
      }
    },
  );

  test(
    'owned gear is skipped and completed collection receives coins',
    () async {
      final p = PlayerProfile()..ownedBalls.add(BallCosmetic.coral);
      expect(p.prizeBall, BallCosmetic.circuit);
      p.ownedBalls.addAll(BallCosmetic.values);
      p.ownedPlatforms.addAll(PlatformStyle.values);
      for (var i = 1; i <= 5; i++) {
        await p.claimDailyPrize(now: DateTime.utc(2026, 9, i));
      }
      expect(p.wallet, 170);
    },
  );

  test(
    'day ten awards gear and day eleven returns to the coin reward',
    () async {
      final p = PlayerProfile();
      for (var day = 1; day <= 10; day++) {
        await p.claimDailyPrize(
          now: DateTime.utc(2026, 9, day),
          platform: day == 10,
        );
      }
      expect(p.dailyPrizes.claimed, 10);
      expect(p.dailyPrizes.nextDay, 11);
      expect(p.ownedBalls, contains(BallCosmetic.coral));
      expect(p.ownedPlatforms, contains(PlatformStyle.copper));
      expect(p.wallet, 140);
      expect(await p.claimDailyPrize(now: DateTime.utc(2026, 9, 10)), isNull);
      expect(
        await p.claimDailyPrize(now: DateTime.utc(2026, 9, 11)),
        '10 coins',
      );
      expect(p.dailyPrizes.displayedDay(DateTime.utc(2026, 9, 11)), 11);
      expect(p.wallet, 150);
    },
  );

  test('saved day counts keep increasing after reload and backup', () async {
    for (final count in [5, 9, 10, 24, 99, 1000]) {
      final date = DateTime.utc(2026, 9, 25);
      final p = PlayerProfile();
      p.dailyPrizes.claimed = count;
      p.dailyPrizes.lastClaim = date;
      await p.saveEconomy();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.dailyPrizes.nextDay, count + 1);
      expect(restored.dailyPrizes.displayedDay(date), count);
      expect(
        restored.dailyPrizes.displayedDay(date.add(const Duration(days: 4))),
        count + 1,
      );
      final decoded = ProgressBackup.decode(
        ProgressBackup.encode(restored),
        testEconomy: false,
      );
      final target = PlayerProfile();
      await ProgressBackup.restore(target, decoded);
      expect(target.dailyPrizes.nextDay, count + 1);
      expect(await target.claimDailyPrize(now: date), isNull);
    }
  });

  for (final count in [5, 9, 10, 99]) {
    testWidgets('prize sheet shows continuing day ${count + 1}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final p = PlayerProfile();
      p.dailyPrizes.claimed = count;
      p.dailyPrizes.lastClaim = DateTime.now().toUtc().subtract(
        const Duration(days: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DailyPrizeSheet(profile: p)),
        ),
      );
      final start =
          count ~/ DailyPrizes.rewardInterval * DailyPrizes.rewardInterval + 1;
      for (var day = start; day < start + DailyPrizes.rewardInterval; day++) {
        expect(find.text('Day $day'), findsOneWidget);
      }
      expect(find.text('Day 1'), findsNothing);
      expect(find.text('TODAY'), findsOneWidget);
      if (DailyPrizes.isGearDay(count + 1)) {
        final choice = find.byKey(const ValueKey('daily-claim-ball'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
      } else {
        final claim = find.text(
          'CLAIM ${DailyPrizes.coinReward(count + 1)} COINS',
        );
        await tester.ensureVisible(claim);
        await tester.tap(claim);
      }
      await tester.pumpAndSettle();
      expect(p.dailyPrizes.claimed, count + 1);
      expect(find.text('Day ${count + 1}'), findsOneWidget);
      expect(find.text('CLAIMED TODAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('backup restores prize progress with the wallet', () async {
    final p = PlayerProfile();
    final date = DateTime.utc(2026, 9, 25);
    await p.claimDailyPrize(now: date);
    final decoded = ProgressBackup.decode(
      ProgressBackup.encode(p),
      testEconomy: false,
    );
    final target = PlayerProfile();
    await ProgressBackup.restore(target, decoded);
    expect(target.wallet, 10);
    expect(await target.claimDailyPrize(now: date), isNull);
    expect(target.dailyPrizes.nextDay, 2);
  });

  testWidgets('prize sheet lists all days and updates after claiming', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = PlayerProfile();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyPrizeSheet(profile: p)),
      ),
    );
    for (var day = 1; day <= 5; day++) {
      expect(find.text('Day $day'), findsOneWidget);
    }
    await tester.tap(find.text('CLAIM 10 COINS'));
    await tester.pumpAndSettle();
    expect(find.text('CLAIMED TODAY'), findsOneWidget);
    expect(find.text('You received 10 coins!'), findsOneWidget);
    expect(p.wallet, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
