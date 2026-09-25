import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/club.dart';
import 'package:balance_arcade/friend_challenge.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test('next goals follow completion, clean and time stars per control', () {
    final p = PlayerProfile()
      ..controlMode = ControlMode.twoFinger
      ..classicLevel = 5;
    // Stars earned with another control unlock the recommended boards.
    for (var level = 1; level <= 4; level++) {
      p.levelRecords['analog:$level'] = const LevelRecord(starMask: 7);
    }
    expect(NextGoal.forProfile(p).level, 5);
    p.levelRecords['twoFinger:5'] = const LevelRecord(starMask: 1);
    expect(NextGoal.forProfile(p).level, 6);
    for (var i = 1; i <= ClassicLevels.count; i++) {
      p.levelRecords['twoFinger:$i'] = const LevelRecord(starMask: 1);
    }
    expect(NextGoal.forProfile(p).title, contains('without a miss'));
    for (var i = 1; i <= ClassicLevels.count; i++) {
      p.levelRecords['twoFinger:$i'] = const LevelRecord(starMask: 7);
    }
    expect(NextGoal.forProfile(p).mode, GameMode.daily);
    p.controlMode = ControlMode.oneFinger;
    expect(NextGoal.forProfile(p).mode, GameMode.classic);
  });
  test(
    'backup round trip retains records, settings, gear and selected controls',
    () async {
      final p = PlayerProfile()
        ..wallet = 80
        ..classicLevel = 9
        ..controlMode = ControlMode.analog
        ..sound = false
        ..tutorialSeen = true
        ..mergeHighest = 4096
        ..infiniteBest = 300;
      p.ownedBalls.add(BallCosmetic.values.last);
      p.selectedBall = BallCosmetic.values.last;
      p.levelRecords['analog:9'] = const LevelRecord(
        starMask: 7,
        bestScore: 1234,
        bestTime: 80,
        attempts: 2,
      );
      p.mazeBestTimes['oneFinger:2'] = 42.5;
      final restored = ProgressBackup.decode(
        ProgressBackup.encode(p),
        testEconomy: false,
      );
      expect(restored.wallet, 80);
      expect(restored.selectedBall, p.selectedBall);
      expect(restored.levelRecord(9).starMask, 7);
      expect(restored.mazeBestTimes, p.mazeBestTimes);
      final target = PlayerProfile();
      await ProgressBackup.restore(target, restored);
      expect(target.mergeHighest, 4096);
      final fresh = PlayerProfile();
      await fresh.load();
      expect(fresh.classicLevel, 9);
      expect(fresh.sound, false);
      expect(fresh.levelRecord(9).bestTime, 80);
      expect(fresh.tutorialSeen, true);
      expect(fresh.wallet, 80);
    },
  );
  test(
    'invalid and mismatched backups are rejected before changing progress',
    () {
      final p = PlayerProfile()..wallet = 50;
      final raw = ProgressBackup.encode(p);
      for (final bad in [
        '',
        '{}',
        raw.substring(0, 20),
        'x' * (ProgressBackup.maxLength + 1),
      ]) {
        expect(
          () => ProgressBackup.decode(bad, testEconomy: false),
          throwsFormatException,
        );
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data['levels'] = {
        'twoFinger:1': {'stars': 7, 'score': -1, 'time': null, 'attempts': 1},
      };
      expect(
        () => ProgressBackup.decode(jsonEncode(data), testEconomy: false),
        throwsFormatException,
      );
      expect(
        () => ProgressBackup.decode(raw, testEconomy: true),
        throwsFormatException,
      );
      expect(p.wallet, 50);
      expect(p.totalStars, 0);
    },
  );
  test('friend codes pin date and controls and reject malformed data', () {
    final date = DailyChallenge.key(DateTime.now());
    final code = FriendChallenge(
      name: 'Player 1',
      date: date,
      control: ControlMode.analog,
      score: 2200,
    ).encode();
    final friend = FriendChallenge.decode(code);
    final p = PlayerProfile();
    p.dailyRecords['analog:$date'] = const LevelRecord(bestScore: 3000);
    p.dailyRecords['oneFinger:$date'] = const LevelRecord(bestScore: 9000);
    expect(friend.yourScore(p), 3000);
    expect(friend.date, date);
    for (final bad in [
      'GILT1.invalid',
      'GILT2.123',
      'x' * 2048,
      FriendChallenge(
        name: 'a',
        date: '2026-02-31',
        control: ControlMode.analog,
        score: 2,
      ).encode(),
    ]) {
      expect(() => FriendChallenge.decode(bad), throwsFormatException);
    }
  });
  testWidgets(
    'club fits a small phone with enlarged text and launches its goal',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      GameMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: ClubScreen(
                profile: PlayerProfile(),
                onPlay: (m, l, d) => selected = m,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('PLAY THIS GOAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PLAY THIS GOAL'));
      await tester.pump();
      expect(selected, GameMode.classic);
    },
  );
}
