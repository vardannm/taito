import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/survival_upgrades.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_painter.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/mode_navigation.dart';

class RotationCanvas implements Canvas {
  final rotations = <double>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #rotate) {
      rotations.add(invocation.positionalArguments.first as double);
    }
    return null;
  }
}

class CosmeticLayerCanvas implements Canvas {
  double rotation = 0;
  bool clipped = false;
  final clipStack = <bool>[];
  final stack = <double>[];
  final bodyRotations = <double>[];
  final effectRotations = <double>[];
  final particlePositions = <Offset>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    switch (invocation.memberName) {
      case #save:
        stack.add(rotation);
        clipStack.add(clipped);
      case #restore:
        rotation = stack.removeLast();
        clipped = clipStack.removeLast();
      case #clipPath:
        clipped = true;
      case #rotate:
        rotation += args.first as double;
      case #drawPath:
        bodyRotations.add(rotation);
      case #drawArc:
        if (!clipped && (args.first as Rect).width > 80)
          effectRotations.add(rotation);
      case #drawCircle:
        final position = args[0] as Offset;
        if (!clipped && ((args[1] as double) > 40 || position.distance > 40)) {
          effectRotations.add(rotation);
          if (position.distance > 40) particlePositions.add(position);
        }
    }
    return null;
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('ball rolls by travelled distance, reverses, pauses, and resets', () {
    final game = BalanceGame()..start(gameMode: GameMode.practice);
    game.velocity = 80;
    final before = game.ballX;
    game.step(1 / 120);
    final angle = game.ballRotation;
    expect(
      angle,
      closeTo((game.ballX - before) / BalanceGame.ballRadius, 1e-9),
    );
    game.setPaused(true);
    game.step(.1);
    expect(game.ballRotation, angle);
    game.setPaused(false);
    game.velocity = -80;
    game.step(1 / 120);
    expect(game.ballRotation, closeTo(0, 1e-9));
    game.start(gameMode: GameMode.practice);
    expect(game.ballRotation, 0);
    game.setControlMode(ControlMode.twoFinger);
    game.left = 400;
    game.right = 480;
    game.velocity = 60;
    final x = game.ballX;
    game.step(1 / 120);
    expect(
      game.ballRotation,
      closeTo(
        (game.ballX - x) * math.sqrt(1 + .25 * .25) / BalanceGame.ballRadius,
        1e-9,
      ),
    );
  });

  test('automatic ascent and a level platform lift do not spin the ball', () {
    final game = BalanceGame()..start(gameMode: GameMode.infinite);
    game.step(.1);
    expect(game.ballRotation, 0);
    game.leftInput = game.rightInput = -1;
    game.step(.1);
    expect(game.ballRotation, 0);
  });

  test(
    'board renderer rotates cosmetic artwork in normal and reduced motion',
    () {
      final game = BalanceGame()
        ..cosmetic = BallCosmetic.circuit
        ..start(gameMode: GameMode.practice)
        ..ballRotation = .73;
      for (final reduced in [false, true]) {
        final canvas = RotationCanvas();
        BoardPainter(
          game,
          reducedMotion: reduced,
        ).paint(canvas, const Size(360, 560));
        expect(canvas.rotations, contains(.73));
      }
    },
  );

  test('outer rings, glows and particles do not inherit ball roll', () {
    for (final ball in BallCosmetic.values) {
      for (final reduced in [false, true]) {
        final canvas = CosmeticLayerCanvas();
        paintCosmetic(
          canvas,
          Offset.zero,
          40,
          ball,
          rotation: .73,
          time: 1,
          reducedMotion: reduced,
        );
        expect(canvas.bodyRotations, contains(.73), reason: ball.name);
        expect(canvas.effectRotations, everyElement(0.0), reason: ball.name);
        if (ball == BallCosmetic.quasar || ball == BallCosmetic.singularity) {
          expect(canvas.effectRotations, isNotEmpty);
          expect(canvas.particlePositions.length, reduced ? 0 : 3);
        }
        expect(canvas.stack, isEmpty);
        expect(canvas.rotation, 0);
      }
    }
  });

  test('orbital particles keep their own animation independent of rolling', () {
    final first = CosmeticLayerCanvas(),
        rolled = CosmeticLayerCanvas(),
        later = CosmeticLayerCanvas();
    paintCosmetic(first, Offset.zero, 40, BallCosmetic.singularity, time: 1);
    paintCosmetic(
      rolled,
      Offset.zero,
      40,
      BallCosmetic.singularity,
      time: 1,
      rotation: 2,
    );
    paintCosmetic(
      later,
      Offset.zero,
      40,
      BallCosmetic.singularity,
      time: 2,
      rotation: 2,
    );
    expect(rolled.particlePositions, first.particlePositions);
    expect(later.particlePositions, isNot(first.particlePositions));
  });

  testWidgets(
    'Infinite HUD displays six bought hearts and a lost heart on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      p.survivalUpgrades[SurvivalUpgrade.hearts] = 3;
      await tester.pumpWidget(ArcadeApp(profile: p));
      await tester.pump();
      await armWorld(tester);
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      game.beginInput();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(game.lives, 6);
      final hearts = find.byKey(const ValueKey('board-hearts'));
      expect(
        tester.widget<Semantics>(hearts).properties.label,
        '6 of 6 hearts remaining',
      );
      for (var i = 0; i < 6; i++) {
        expect(
          tester.widget<Icon>(find.byKey(ValueKey('board-heart-$i'))).icon,
          Icons.favorite_rounded,
        );
      }
      game.board
        ..clear()
        ..add(Hole(game.ballX, game.ballY));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.lives, 5);
      expect(
        tester.widget<Semantics>(hearts).properties.label,
        '5 of 6 hearts remaining',
      );
      expect(
        tester.widget<Icon>(find.byKey(const ValueKey('board-heart-5'))).icon,
        Icons.favorite_border_rounded,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
