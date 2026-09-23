import 'support/mode_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/next_goal.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('all star thresholds are reachable and exact, with level 1 free', () {
    expect(ClassicLevels.isUnlocked(1, 0), isTrue);
    for (var level = 2; level <= ClassicLevels.count; level++) {
      final stars = ClassicLevels.requiredStars(level);
      expect(stars, (level - 1) * 2);
      expect(stars, lessThanOrEqualTo((level - 1) * 3));
      expect(ClassicLevels.isUnlocked(level, stars - 1), isFalse);
      expect(ClassicLevels.isUnlocked(level, stars), isTrue);
    }
    expect(ClassicLevels.isUnlocked(0, 150), isFalse);
    expect(ClassicLevels.isUnlocked(ClassicLevels.count + 1, 1000), isFalse);
  });

  test(
    'unlocks use unique Classic stars across controls, persist and cost nothing',
    () async {
      final p = PlayerProfile();
      p.levelRecords['twoFinger:1'] = const LevelRecord(starMask: 1);
      p.levelRecords['analog:1'] = const LevelRecord(starMask: 1);
      p.dailyRecords['twoFinger:2026-09-16'] = const LevelRecord(starMask: 7);
      expect(p.totalStars, 1);
      expect(p.selectClassicLevel(2), isFalse);
      p.levelRecords['oneFinger:1'] = const LevelRecord(starMask: 3);
      expect(p.totalStars, 2);
      expect(p.selectClassicLevel(2), isTrue);
      expect(p.totalStars, 2);
      await p.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.isClassicLevelUnlocked(2), isTrue);
      expect(restored.classicLevel, 2);
      expect(restored.isClassicLevelUnlocked(3), isFalse);
      expect(restored.selectClassicLevel(50), isFalse);
      expect(restored.classicLevel, 2);
    },
  );

  test('goals recommend earning a missing star instead of a locked level', () {
    final p = PlayerProfile()..classicLevel = 50;
    expect(NextGoal.forProfile(p).level, 1);
    p.levelRecords['twoFinger:1'] = const LevelRecord(starMask: 1);
    final goal = NextGoal.forProfile(p);
    expect(goal.level, 1);
    expect(goal.title, contains('without a miss'));
    p.levelRecords['twoFinger:1'] = const LevelRecord(starMask: 3);
    expect(NextGoal.forProfile(p).level, 2);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('locked cards show required stars and cannot launch at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? selected;
      Future<void> show(int stars) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: LevelPicker(
                selected: 1,
                totalStars: stars,
                onSelected: (level) => selected = level,
              ),
            ),
          ),
        ),
      );
      await show(1);
      expect(find.text('1 / 2 STARS'), findsOneWidget);
      expect(
        tester.widget<InkWell>(find.byKey(const ValueKey('level-2'))).onTap,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('level-2')));
      expect(selected, isNull);
      await tester.tap(find.byKey(const ValueKey('level-1')));
      expect(selected, 1);
      await show(2);
      await tester.tap(find.byKey(const ValueKey('level-2')));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('win screen requires enough stars before advancing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: p));
    await openClassicLevels(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('level-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    void win(int misses) {
      game.phase = GamePhase.over;
      game.won = true;
      game.completed = 10;
      game.misses = misses;
      game.elapsed = 9999;
    }

    win(1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(p.totalStars, 1);
    expect(find.text('NEXT LEVEL'), findsNothing);
    await tester.tap(find.text('EARN MORE STARS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('level-2'))).onTap,
      isNull,
    );
    Navigator.of(tester.element(find.byType(LevelPicker))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('RETRY THIS BOARD'));
    await tester.pump();
    win(0);
    await tester.pump(const Duration(milliseconds: 16));
    expect(p.totalStars, 2);
    await tester.tap(find.text('NEXT LEVEL'));
    await tester.pump();
    expect(game.level, 2);
    expect(game.finished, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'stale selections cannot bypass the central Classic launch gate',
    (tester) async {
      final p = PlayerProfile()
        ..classicLevel = 50
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: p));
      final dynamic screen = tester.state(find.byType(GameScreen));
      screen.start(GameMode.classic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(game.infinite, isTrue);
      expect(game.waitingForInput, isTrue);
      expect(find.byType(LevelPicker), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
