import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'game_test.dart' show advance, placeAt;

// Isolate score/idle-floor tests from the independent trap collision system.
void advanceWithoutTraps(BalanceGame game, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) {
    game.board.clear();
    game.specialHazards.clear();
    game.step(1 / 120);
  }
}

void placeAtSafeHeight(BalanceGame game, double height) {
  final y = BalanceGame.infiniteStart - BalanceGame.ballRadius - height;
  game.cameraOffset = math.max(0, 300 - y);
  game.ensureInfiniteBoard();
  final x = [180.0, 70.0, 290.0, 120.0, 240.0].firstWhere(
    (x) => game.board.every(
      (h) => math.pow(x - h.x, 2) + math.pow(y - h.y, 2) > 18 * 18,
    ),
  );
  game.left = game.right = y + BalanceGame.ballRadius;
  game.ballX = x;
  game.velocity = game.leftSpeed = game.rightSpeed = 0;
  game.step(1 / 120);
}

void main() {
  test('infinite contains hazards only and scoring depends on peak height', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    expect(game.board, isNotEmpty);
    expect(game.board.every((h) => h.target == 0), isTrue);
    placeAtSafeHeight(game, 50);
    expect(game.score, 5);
    placeAtSafeHeight(game, 20);
    expect(game.score, 5);
    placeAtSafeHeight(game, 50);
    expect(game.score, 5);
    placeAtSafeHeight(game, 80);
    expect(game.score, 8);
    expect(game.completed, 0);
    expect(game.lives, 1);
  });
  test(
    'camera and generated hazards continue far beyond the original board',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      for (int i = 1; i <= 1000; i++) {
        game.specialHazards.clear();
        game.stallTime = 0;
        placeAtSafeHeight(game, i * 5.0);
      }
      expect(game.finished, isFalse);
      expect(game.won, isFalse);
      expect(game.score, 500);
      expect(game.cameraOffset, greaterThan(4500));
      expect(game.screenY(game.ballY), closeTo(300, .01));
      expect(game.board.length, lessThan(40));
      expect(game.board.every((h) => h.target == 0), isTrue);
    },
  );
  test('staying still raises the red floor and ends the run', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    advanceWithoutTraps(game, 2.8);
    expect(game.dangerActive, isFalse);
    expect(game.score, greaterThan(0));
    advanceWithoutTraps(game, .5);
    expect(game.dangerActive, isTrue);
    expect(game.dangerY, lessThan(580));
    advanceWithoutTraps(game, 8);
    expect(game.finished, isTrue);
    expect(game.lives, 0);
    expect(game.message, contains('red caught'));
  });
  test('old-height movement cannot farm score or reset the stall timer', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    placeAtSafeHeight(game, 60);
    advanceWithoutTraps(game, 1.5);
    final peakScore = game.score;
    for (int i = 0; i < 30; i++) {
      game.board.clear();
      game.specialHazards.clear();
      // Keep the floor offscreen while this test teleports the camera backward.
      game.dangerY = 580;
      placeAtSafeHeight(game, i.isEven ? 30 : 60);
      advanceWithoutTraps(game, .06);
    }
    expect(game.score, peakScore);
    expect(game.dangerActive, isTrue);
  });
  test(
    'deliberate steering stops red growth; pause freezes the danger timer',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      advance(game, 3.2);
      game.setPaused(true);
      final red = game.dangerY, stall = game.stallTime;
      advance(game, 6);
      expect(game.dangerY, red);
      expect(game.stallTime, stall);
      game.setPaused(false);
      game.grabPivot(0);
      game.dragPivot(0, -10);
      advance(game, .05);
      game.releasePivot(0);
      expect(game.dangerActive, isFalse);
      final recoveredRed = game.screenY(game.dangerY);
      advance(game, .3);
      expect(game.screenY(game.dangerY), closeTo(recoveredRed, .001));
    },
  );
  test(
    'every hole ends Infinite immediately and replay starts at ground level',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      placeAt(game, game.board.first);
      advance(game, 1);
      expect(game.finished, isTrue);
      expect(game.won, isFalse);
      game.start(gameMode: game.mode);
      expect(game.cameraOffset, 0);
      expect(game.score, 0);
      expect(game.lives, 1);
      expect(game.dangerY, 580);
      expect(game.stallTime, 0);
    },
  );
  test('climb records remain separate from Classic and Practice', () {
    final profile = PlayerProfile()..best = 999;
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.score = 500;
    game.phase = GamePhase.over;
    expect(profile.recordResult(game), isTrue);
    expect(profile.best, 999);
    expect(profile.runs, 0);
    expect(profile.infiniteBest, 500);
    game.start(gameMode: GameMode.practice);
    game.score = 99999;
    game.phase = GamePhase.over;
    expect(profile.recordResult(game), isFalse);
    expect(profile.infiniteBest, 500);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('climb HUD fits $size and contains no target indicator', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      await tester.tap(find.text('INFINITE'));
      await tester.pump();
      expect(find.text('HEIGHT / METERS'), findsOneWidget);
      expect(find.text('THE RUSH'), findsOneWidget);
      expect(find.textContaining('HOLE 01'), findsNothing);
      expect(find.byType(PivotBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
