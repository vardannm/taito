import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_world.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_painter.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/mode_world_preview.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/mode_navigation.dart';
import 'support/shop_navigation.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('all worlds retain distinct palettes at base and maximum combo', () {
    final base = <int>{}, charged = <int>{};
    for (final ball in BallCosmetic.values) {
      final game = BalanceGame()
        ..cosmetic = ball
        ..start(gameMode: GameMode.infinite);
      base.add(boardFieldColors(game)[1].toARGB32());
      game.survival.visualCombo = 1;
      charged.add(boardFieldColors(game)[1].toARGB32());
      game.survival.breakCombo();
      expect(boardFieldColors(game), BallWorld.of(ball).field);
    }
    expect(base.length, BallCosmetic.values.length);
    expect(charged.length, BallCosmetic.values.length);
  });

  test('pale worlds sink into a rich hue, not grey, at the top combos', () {
    for (final ball in [BallCosmetic.prism, BallCosmetic.malachite]) {
      final game = BalanceGame()
        ..cosmetic = ball
        ..start(gameMode: GameMode.infinite);
      game.survival.visualCombo = 1;
      final field = HSVColor.fromColor(boardFieldColors(game)[1]);
      expect(field.saturation, greaterThan(.45), reason: '$ball');
      expect(field.value, lessThan(.5), reason: '$ball');
    }
  });

  test('HUD foreground stays legible for every world, mode and combo fade', () {
    final game = BalanceGame();
    for (final mode in GameMode.values) {
      game.start(gameMode: mode);
      for (final ball in BallCosmetic.values) {
        game.cosmetic = ball;
        for (var step = 0; step <= (game.infinite ? 40 : 0); step++) {
          game.survival.visualCombo = step / 40;
          for (final point in [
            const Offset(110, 60),
            const Offset(180, 270),
            const Offset(315, 510),
          ]) {
            expect(
              contrast(
                infiniteBoardInk(game, point),
                infiniteFieldColor(game, point),
              ),
              greaterThanOrEqualTo(4.5),
              reason: '$mode / $ball / $step',
            );
          }
        }
      }
    }
  });

  testWidgets('shop purchase equips its world across mode changes and reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..wallet = 200;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('board-shop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final buy = find.byKey(const ValueKey('buy-circuit'));
    await revealShopBall(tester, BallCosmetic.circuit);
    await tester.pump();
    final preview =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('world-preview-circuit')),
                )
                .painter!
            as BallWorldPreview;
    expect(preview.ball, BallCosmetic.circuit);
    expect(find.text('Circuit Garden · World included'), findsOneWidget);
    await tester.tap(buy);
    await tester.pump();
    expect(profile.selectedBall, BallCosmetic.circuit);
    expect(profile.wallet, 200 - BallCosmetic.circuit.cost);
    await tester.tap(find.byTooltip('Done shopping'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    for (var index = 0; index < 3; index++) {
      if (index > 0) await selectWorld(tester, index);
      expect(game.cosmetic, BallCosmetic.circuit);
      expect(boardFieldColors(game), BallWorld.of(BallCosmetic.circuit).field);
      expect(game.waitingForInput, isTrue);
      expect(game.elapsed, 0);
      for (final widget in tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      )) {
        if (widget.painter case final ModeWorldPreview preview) {
          expect(preview.game.cosmetic, BallCosmetic.circuit);
          expect(preview.game.elapsed, 0);
        }
      }
    }
    await profile.save();
    final restored = PlayerProfile();
    await restored.load();
    expect(restored.selectedBall, BallCosmetic.circuit);
    expect(BallWorld.of(restored.selectedBall).name, 'Circuit Garden');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large text still fits the themed shop cards', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    await tester.tap(find.byKey(const ValueKey('board-shop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await revealShopBall(tester, BallCosmetic.coral);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
