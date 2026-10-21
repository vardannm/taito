import 'dart:convert';
import 'dart:math' as math;

import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/mode_navigation.dart';

void collectStar(BalanceGame game) {
  game.board.clear();
  game.levelStar = LevelStar(180, 450);
  game.left = game.right = 500;
  game.grabPivot(0);
  game.grabPivot(1);
  game.dragPivot(0, -100);
  game.dragPivot(1, -100);
  game.step(1 / 120);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'every Classic board has one deterministic reachable star and no coins',
    () {
      for (var level = 1; level <= ClassicLevels.count; level++) {
        final game = BalanceGame()..start(levelNumber: level);
        final star = game.levelStar!;
        expect(game.coins, isEmpty);
        final replay = ClassicLevels.starForLevel(level);
        expect((star.x, star.y), (replay.x, replay.y));
        expect(star.collected, isFalse);
        for (final hole in game.board) {
          expect(
            math.sqrt(
              math.pow(star.x - hole.x, 2) + math.pow(star.y - hole.y, 2),
            ),
            greaterThanOrEqualTo(hole.target > 0 ? 34 : 25),
            reason: 'Level $level',
          );
        }
        for (final spider in game.spiders) {
          expect(
            math.sqrt(
              math.pow(star.x - spider.homeX, 2) +
                  math.pow(star.y - spider.homeY, 2),
            ),
            greaterThanOrEqualTo(spider.zoneRadius + 12),
            reason: 'Level $level',
          );
        }
        expect(
          ClassicLevels.hasSafeRoutes([
            ...game.board,
            Hole(star.x, star.y, target: 11),
          ], game.spiders),
          isTrue,
          reason: 'Reachable star on level $level',
        );
      }
    },
  );

  test(
    'a swept pickup saves immediately, survives failure, and cannot pay twice',
    () async {
      final profile = PlayerProfile()..wallet = 73;
      final game = BalanceGame()..start();
      collectStar(game);
      expect(game.levelStarCollected, isTrue);
      expect(game.event, GameEvent.star);
      expect(game.score, 0);
      expect(game.coinsCollected, 0);
      expect(game.pivotTargets.every((p) => p != null), isTrue);
      expect(profile.bankLevelStar(game), isTrue);
      expect(profile.totalStars, 1);
      expect(profile.wallet, 73);
      expect(profile.levelRecord(1, game.controlMode).attempts, 0);
      expect(profile.bankLevelStar(game), isFalse);
      await Future<void>.delayed(Duration.zero);
      final immediatelyRestored = PlayerProfile();
      await immediatelyRestored.load();
      expect(immediatelyRestored.totalStars, 1);
      game.resetBall();
      expect(game.levelStarCollected, isTrue);
      game.phase = GamePhase.over;
      game.won = false;
      profile.recordResult(game);
      await profile.save();
      final loaded = PlayerProfile();
      await loaded.load();
      expect(loaded.totalStars, 1);
      expect(loaded.wallet, 73);
      expect(loaded.hasCollectedLevelStar(1), isTrue);
      expect(loaded.levelRecord(1, ControlMode.oneFinger).starMask, 8);
      final retry = BalanceGame()
        ..levelStarAlreadyOwned = loaded.hasCollectedLevelStar(1)
        ..setControlMode(ControlMode.oneFinger)
        ..start();
      expect(retry.levelStar, isNull);
      collectStar(
        retry,
      ); // Even an injected duplicate cannot grant another star.
      expect(loaded.bankLevelStar(retry), isFalse);
      retry.phase = GamePhase.over;
      retry.won = true;
      loaded.recordResult(retry);
      expect(loaded.totalStars, 4);
    },
  );

  test('a hole before the star stops collection on the same sweep', () {
    final game = BalanceGame()..start();
    game.board
      ..clear()
      ..add(const Hole(180, 480));
    game.levelStar = LevelStar(180, 450);
    game.left = game.right = 500;
    game.grabPivot(0);
    game.grabPivot(1);
    game.dragPivot(0, -100);
    game.dragPivot(1, -100);
    game.step(1 / 120);
    expect(game.phase, GamePhase.sinking);
    expect(game.levelStarCollected, isFalse);
  });

  test(
    'new stars round-trip in backups while old three-star saves still load',
    () async {
      final profile = PlayerProfile();
      profile.levelRecords['twoFinger:1'] = const LevelRecord(
        starMask: 15,
        bestScore: 9000,
      );
      final raw = ProgressBackup.encode(profile);
      final restored = PlayerProfile();
      await ProgressBackup.restore(
        restored,
        ProgressBackup.decode(raw, testEconomy: false),
      );
      expect(restored.totalStars, 4);
      expect(restored.hasCollectedLevelStar(1), isTrue);
      final legacy = jsonDecode(raw) as Map<String, dynamic>;
      legacy['levels']['twoFinger:1']['stars'] = 7;
      final old = ProgressBackup.decode(jsonEncode(legacy), testEconomy: false);
      expect(old.totalStars, 3);
      expect(old.hasCollectedLevelStar(1), isFalse);
    },
  );

  test('Daily, Infinite and Practice do not receive Classic bonus stars', () {
    for (final mode in [
      GameMode.daily,
      GameMode.infinite,
      GameMode.practice,
      GameMode.merge2048,
    ]) {
      final game = BalanceGame()..start(gameMode: mode);
      expect(game.levelStar, isNull);
      expect(game.earnedStarMask & 8, 0);
    }
    final daily = BalanceGame()..start(gameMode: GameMode.daily);
    expect(daily.coins, isNotEmpty);
  });

  testWidgets(
    'Classic hides score, banks a star in live play, and hides it on replay',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      profile.levelRecords['oneFinger:1'] = const LevelRecord(bestScore: 54321);
      await tester.pumpWidget(ArcadeApp(profile: profile));
      await selectWorld(tester, 1);
      await startWorld(tester);
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.score = 12345;
      collectStar(game);
      await tester.pump(const Duration(milliseconds: 20));
      expect(profile.totalStars, 1);
      expect(find.text('12345'), findsNothing);
      expect(find.text('COLLECTED'), findsOneWidget);
      game.phase = GamePhase.over;
      game.won = false;
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('12345'), findsNothing);
      expect(find.textContaining('Saved: 1/4 stars'), findsOneWidget);
      final dynamic state = tester.state(find.byType(GameScreen));
      state.start(GameMode.classic);
      await tester.pump();
      expect(game.levelStar, isNull);
      expect(game.coins, isEmpty);
      state.showSettings();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Classic best'), findsNothing);
      expect(find.textContaining('54321'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
