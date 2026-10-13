import 'dart:async';

import 'package:balance_arcade/app_analytics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewarded_revive_ads.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/mode_navigation.dart';

class FakeReviveAds implements RewardedReviveAds {
  @override
  bool supported = true;
  int calls = 0;
  bool disposed = false;
  Completer<ReviveAdResult>? pending;

  @override
  Future<ReviveAdResult> show() {
    calls++;
    pending = Completer<ReviveAdResult>();
    return pending!.future;
  }

  @override
  void dispose() => disposed = true;
}

Future<BalanceGame> launchRevive(
  WidgetTester tester,
  PlayerProfile profile,
  FakeReviveAds ads, {
  AppAnalytics? analytics,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ArcadeApp(profile: profile, analytics: analytics, reviveAds: ads),
  );
  await tester.pump();
  await startWorld(tester);
  await tester.pump(const Duration(milliseconds: 600));
  final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
  expect(game.waitingForInput, isFalse);
  return game;
}

// Exercise the actual fatal collision and sinking animation before game over.
Future<void> loseLastHeart(WidgetTester tester, BalanceGame game) async {
  game.lives = 1;
  game.survival.shield = game.survival.recovery = 0;
  game.board
    ..clear()
    ..add(Hole(game.ballX, game.ballY));
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(game.lives, 0);
  expect(game.finished, isTrue);
}

void main() {
  late PlayerProfile profile;
  late FakeReviveAds ads;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..controlMode = ControlMode.boardTilt;
    ads = FakeReviveAds();
  });

  test('revive preserves the run and protects against the fatal obstacle', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.survival.points = 730;
    game.coinsCollected = 7;
    game.elapsed = 38;
    game.maxHeight = 500;
    game.lives = 1;
    game.board
      ..clear()
      ..add(Hole(game.ballX, game.ballY));
    game.step(.02);
    for (var i = 0; i < 8; i++) {
      game.step(.1);
    }
    expect(game.finished, isTrue);
    final serial = game.runSerial;
    final position = (game.ballX, game.left, game.right, game.cameraOffset);
    final score = game.score, elapsed = game.elapsed;
    final holes = game.board.toList();

    expect(game.reviveInfinite(), isTrue);
    expect(game.runSerial, serial);
    expect((game.ballX, game.left, game.right, game.cameraOffset), position);
    expect(game.board, holes);
    expect(game.score, score);
    expect(game.elapsed, elapsed);
    expect(game.coinsCollected, 7);
    expect(game.maxHeight, 500);
    expect(game.lives, 1);
    expect(game.survival.recovery, 3);
    expect(game.canControl, isTrue);
    for (var i = 0; i < 5; i++) {
      game.step(.1);
    }
    expect(game.lives, 1);
    expect(game.reviveInfinite(), isFalse);

    game.survival.recovery = 0;
    game.board
      ..clear()
      ..add(Hole(game.ballX, game.ballY));
    game.step(.02);
    for (var i = 0; i < 8; i++) {
      game.step(.1);
    }
    expect(game.finished, isTrue);
    expect(game.canReviveInfinite, isFalse);
    expect(game.reviveInfinite(), isFalse);
    game.start(gameMode: GameMode.infinite);
    game.lives = 0;
    game.phase = GamePhase.over;
    expect(game.canReviveInfinite, isTrue);
  });

  test('reviving is restricted to a lost Infinite run', () {
    for (final mode in GameMode.values) {
      final game = BalanceGame()..start(gameMode: mode);
      expect(game.reviveInfinite(), isFalse);
      game.lives = 0;
      game.phase = GamePhase.over;
      expect(game.reviveInfinite(), mode == GameMode.infinite);
    }
  });

  testWidgets('reward continues once and records only the final result', (
    tester,
  ) async {
    final events = <String>[];
    final game = await launchRevive(
      tester,
      profile,
      ads,
      analytics: AppAnalytics(send: (name, _) async => events.add(name)),
    );
    game.survival.points = 900;
    await loseLastHeart(tester, game);
    expect(find.byKey(const ValueKey('revive-offer')), findsOneWidget);
    expect(profile.infiniteRuns, 0);
    expect(events.where((e) => e == 'run_finished'), isEmpty);
    final serial = game.runSerial, score = game.score;
    expect(score, greaterThanOrEqualTo(900));
    final elapsed = game.elapsed;
    await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
    await tester.tap(find.byKey(const ValueKey('decline-revive')));
    expect(ads.calls, 1);
    expect(game.finished, isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(game.elapsed, elapsed);
    ads.pending!.complete(ReviveAdResult.earned);
    await tester.pump();
    expect(game.lives, 1);
    expect(game.finished, isFalse);
    expect(game.runSerial, serial);
    expect(game.score, score);
    expect(profile.infiniteRuns, 0);
    expect(find.byKey(const ValueKey('revive-offer')), findsNothing);

    game.survival.points = 1700;
    game.maxHeight = 900;
    await loseLastHeart(tester, game);
    expect(find.byKey(const ValueKey('revive-offer')), findsNothing);
    expect(profile.infiniteRuns, 1);
    expect(profile.infiniteBestScore, game.score);
    expect(profile.infiniteBestScore, greaterThan(score));
    expect(profile.infiniteBest, game.metres);
    expect(events.where((e) => e == 'run_started'), hasLength(1));
    expect(events.where((e) => e == 'run_finished'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    expect(profile.infiniteRuns, 1);
    expect(tester.takeException(), isNull);
  });

  for (final result in [ReviveAdResult.dismissed, ReviveAdResult.unavailable]) {
    testWidgets('$result grants no heart and allows retry or decline', (
      tester,
    ) async {
      final game = await launchRevive(tester, profile, ads);
      await loseLastHeart(tester, game);
      await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
      await tester.pump();
      ads.pending!.complete(result);
      await tester.pump();
      expect(game.lives, 0);
      expect(game.canReviveInfinite, isTrue);
      expect(profile.infiniteRuns, 0);
      expect(
        find.textContaining(
          result == ReviveAdResult.dismissed
              ? 'Finish watching'
              : 'No ad available',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
      await tester.pump();
      expect(ads.calls, 2);
      ads.pending!.complete(ReviveAdResult.unavailable);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('decline-revive')));
      await tester.tap(find.byKey(const ValueKey('decline-revive')));
      await tester.pump();
      expect(find.byKey(const ValueKey('revive-offer')), findsNothing);
      expect(game.lives, 0);
      expect(profile.infiniteRuns, 1);
      await tester.pumpWidget(const SizedBox());
      expect(profile.infiniteRuns, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a new run gets its own offer', (tester) async {
    final game = await launchRevive(tester, profile, ads);
    await loseLastHeart(tester, game);
    await tester.tap(find.byKey(const ValueKey('decline-revive')));
    await tester.pump();
    final dynamic state = tester.state(find.byType(GameScreen));
    state.start(GameMode.infinite);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await startWorld(tester);
    await loseLastHeart(tester, game);
    expect(find.byKey(const ValueKey('revive-offer')), findsOneWidget);
    expect(profile.infiniteRuns, 1);
    await tester.pumpWidget(const SizedBox());
    expect(profile.infiniteRuns, 2);
  });

  testWidgets('unsupported platforms finish without offering an ad', (
    tester,
  ) async {
    ads.supported = false;
    final game = await launchRevive(tester, profile, ads);
    await loseLastHeart(tester, game);
    expect(find.byKey(const ValueKey('revive-offer')), findsNothing);
    expect(profile.infiniteRuns, 1);
    expect(ads.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late reward after disposal does not revive or double-record', (
    tester,
  ) async {
    final game = await launchRevive(tester, profile, ads);
    await loseLastHeart(tester, game);
    await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(ads.disposed, isTrue);
    ads.pending!.complete(ReviveAdResult.earned);
    await tester.pump();
    expect(game.finished, isTrue);
    expect(game.lives, 0);
    expect(profile.infiniteRuns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward arriving in background resumes into a paused game', (
    tester,
  ) async {
    final game = await launchRevive(tester, profile, ads);
    await loseLastHeart(tester, game);
    await tester.tap(find.byKey(const ValueKey('watch-revive-ad')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    ads.pending!.complete(ReviveAdResult.earned);
    await tester.pump();
    expect(game.lives, 1);
    expect(game.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
