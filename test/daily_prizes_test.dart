import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/daily_prize_sheet.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
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
    'five-day cycle keeps missed days, unlocks chosen gear and repeats',
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
        expect(
          await p.claimDailyPrize(now: DateTime.utc(2026, 9, 11)),
          '10 coins',
        );
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
