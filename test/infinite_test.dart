import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'game_test.dart' show advance, placeAt;

void clearRound(BalanceGame game) {
  for (int i = 0; i < 10; i++) {
    placeAt(game, game.activeHole);
    advance(game, 1.5);
  }
}

void main() {
  test(
    'infinite continues beyond ten, preserves lives and alternates routes',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      placeAt(game, game.board.firstWhere((h) => h.target == 0));
      advance(game, 1.5);
      expect(game.lives, 2);
      clearRound(game);
      expect(game.finished, isFalse);
      expect(game.won, isFalse);
      expect(game.round, 2);
      expect(game.target, 1);
      expect(game.completed, 10);
      expect(game.roundCompleted, 0);
      expect(game.lives, 2);
      expect(game.streak, 10);
      expect(game.activeHole.x, 360 - BalanceGame.holes.first.x);
      final score = game.score;
      clearRound(game);
      expect(game.round, 3);
      expect(game.completed, 20);
      expect(game.score, greaterThan(score));
      expect(game.activeHole.x, BalanceGame.holes.first.x);
    },
  );
  test('infinite difficulty rises then caps and never auto-wins', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    final first = game.difficulty;
    for (int i = 0; i < 10; i++) {
      clearRound(game);
    }
    expect(game.completed, 100);
    expect(game.round, 11);
    expect(game.difficulty, greaterThan(first));
    expect(game.difficulty, closeTo(1.4, .0001));
    expect(game.finished, isFalse);
    clearRound(game);
    expect(game.difficulty, closeTo(1.4, .0001));
  });
  test('round bonus awarded once and route changes only after the return', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    for (int i = 0; i < 9; i++) {
      placeAt(game, game.activeHole);
      advance(game, 1.5);
    }
    final prior = game.score;
    placeAt(game, game.activeHole);
    final award = game.lastAward;
    expect(award, greaterThanOrEqualTo(1000 * game.multiplier + 1000));
    expect(game.score, prior + award);
    expect(game.round, 1);
    expect(game.roundCompleted, 10);
    game.setPaused(true);
    advance(game, 2);
    expect(game.round, 1);
    game.setPaused(false);
    advance(game, 1.5);
    expect(game.round, 2);
    expect(game.score, prior + award);
    expect(game.leftInput, 0);
    expect(game.rightInput, 0);
  });
  test(
    'infinite ends after three misses and replay retains the selected mode',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      clearRound(game);
      for (int i = 0; i < 3; i++) {
        placeAt(game, game.board.firstWhere((h) => h.target == 0));
        advance(game, 1.5);
      }
      expect(game.finished, isTrue);
      expect(game.won, isFalse);
      game.start(gameMode: game.mode);
      expect(game.infinite, isTrue);
      expect(game.round, 1);
      expect(game.completed, 0);
      expect(game.score, 0);
      expect(game.lives, 3);
      game.home();
      expect(game.started, isFalse);
      expect(game.mode, GameMode.classic);
    },
  );
  test('infinite records are separate from classic and practice', () {
    final profile = PlayerProfile()..best = 999;
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.score = 5000;
    game.round = 3;
    game.phase = GamePhase.over;
    expect(profile.recordResult(game), isTrue);
    expect(profile.best, 999);
    expect(profile.runs, 0);
    expect(profile.infiniteBest, 5000);
    expect(profile.infiniteRound, 3);
    expect(profile.infiniteRuns, 1);
    game.score = 3000;
    expect(profile.recordResult(game), isFalse);
    expect(profile.infiniteBest, 5000);
    game.start(gameMode: GameMode.practice);
    game.score = 99999;
    game.phase = GamePhase.over;
    expect(profile.recordResult(game), isFalse);
    expect(profile.best, 999);
    expect(profile.infiniteRuns, 2);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('infinite button starts a playable run at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = PlayerProfile()
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      expect(find.text('CLASSIC'), findsOneWidget);
      expect(find.text('INFINITE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('INFINITE'));
      await tester.pump();
      expect(find.text('R1 / HOLE 01'), findsOneWidget);
      expect(find.byType(ThumbRocker), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
