import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/control_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  for (final special in [false, true]) {
    test(
      'a fast camera lift resolves $special hole contact before pruning',
      () {
        final g = BalanceGame()
          ..setControlMode(ControlMode.oneFinger)
          ..start(gameMode: GameMode.infinite);
        g.board.clear();
        if (special) {
          g.specialHazards.add(
            SpecialHazard(
              HazardKind.formingHole,
              x: 180,
              y: 420,
              warningSeconds: 0,
              liveSeconds: double.infinity,
              cameraOffset: 0,
            ),
          );
        } else {
          g.board.add(const Hole(180, 420));
        }
        g.grabControl();
        g.dragControlVertical(-500);
        g.step(1 / 120);
        expect(g.lives, 2);
        expect(g.misses, 1);
      },
    );
  }
  test(
    'recovery preserves hole identities, positions, order and active hazard warnings',
    () {
      final g = BalanceGame(seed: 7)..start(gameMode: GameMode.infinite);
      g.board.add(Hole(g.ballX, g.ballY));
      final holes = g.board.toList(),
          positions = g.board.map((h) => (h.x, h.y)).toList();
      final warning = SpecialHazard(
        HazardKind.formingHole,
        x: 290,
        y: 200,
        warningSeconds: 2,
        cameraOffset: g.cameraOffset,
      );
      g.specialHazards.add(warning);
      final camera = g.cameraOffset, serial = g.runSerial;
      g.step(1 / 120);
      expect(g.lives, 2);
      expect(g.phase, GamePhase.playing);
      expect(g.runSerial, serial);
      expect(g.board, orderedEquals(holes));
      expect(g.board.map((h) => (h.x, h.y)), positions);
      expect(g.specialHazards, contains(same(warning)));
      expect(warning.age, closeTo(1 / 120, 1e-8));
      expect(g.cameraOffset - camera, closeTo(68 / 120, 1e-7));
      expect(g.survival.recovery, 2.5);
      expect(g.screenY(g.ballY), inInclusiveRange(390, 460));
    },
  );
  test(
    'forming holes lock to world coordinates when opening and follow manual camera displacement',
    () {
      final h = SpecialHazard(
        HazardKind.formingHole,
        x: 180,
        y: 240,
        cameraOffset: 100,
        liveSeconds: double.infinity,
      );
      h.step(1, 68, cameraOffset: 168);
      expect(h.y, 240);
      expect(h.worldY, isNull);
      h.step(1.1, 68, cameraOffset: 300);
      final world = h.worldY!;
      expect(h.y - world, closeTo(300, 1e-6));
      final before = h.y;
      h.step(1 / 120, 68, cameraOffset: 475);
      expect(h.worldY, world);
      expect(h.y - before, closeTo(175, 1e-6));
      h.step(10, 68, cameraOffset: 515);
      expect(h.worldY, world);
      expect(h.expired, false);
    },
  );
  test(
    'game integration anchors an open forming hole during a fast platform lift',
    () {
      final g = BalanceGame()..start(gameMode: GameMode.infinite);
      g.board.clear();
      g.survival.shield = 10;
      final h = SpecialHazard(
        HazardKind.formingHole,
        x: 80,
        y: 200,
        warningSeconds: 0,
        liveSeconds: double.infinity,
        cameraOffset: 0,
      );
      g.specialHazards.add(h);
      g.step(1 / 120);
      final y = h.worldY;
      g.grabPivot(0);
      g.grabPivot(1);
      g.dragPivot(0, -260);
      g.dragPivot(1, -260);
      g.step(1 / 120);
      g.dragPivot(0, -100);
      g.dragPivot(1, -100);
      g.step(1 / 120);
      expect(g.cameraOffset, greaterThan(20));
      expect(h.worldY, y);
      expect(h.y - g.cameraOffset, closeTo(y!, 1e-6));
    },
  );
  test(
    'early layouts are sparse; full density is reserved for 60000 points and restart resets it',
    () {
      expect(InfiniteTuning.densityAt(0), 0);
      expect(InfiniteTuning.densityAt(59999), lessThan(1));
      expect(InfiniteTuning.densityAt(60000), 1);
      var early = 0, middle = 0, late = 0;
      for (var seed = 0; seed < 40; seed++) {
        for (final score in [0, 15000, 60000]) {
          final g = BalanceGame(seed: seed)..start(gameMode: GameMode.infinite);
          g.score = score;
          g.maxHeight = score / 2.0;
          g.cameraOffset = 1000;
          g.ensureInfiniteBoard();
          if (score == 0) early += g.board.length;
          if (score == 15000) middle += g.board.length;
          if (score == 60000) late += g.board.length;
          g.score = 50000;
          g.start(gameMode: GameMode.infinite);
          expect(g.board.length, lessThanOrEqualTo(6));
          expect(g.score, 0);
        }
      }
      expect(middle, greaterThan(early));
      expect(late, greaterThan(early * 3));
    },
  );
  test(
    'owned balls and platforms give additive gear multipliers to both kinds of Infinite points',
    () {
      final plain = BalanceGame()..start(gameMode: GameMode.infinite);
      final boosted = BalanceGame()
        ..cosmetic = BallCosmetic.reactor
        ..platformStyle = PlatformStyle.solar
        ..start(gameMode: GameMode.infinite);
      expect(boosted.survival.scoreBoost, 3);
      for (final g in [plain, boosted]) {
        g.maxHeight = 100;
        g.board.clear();
        g.survival.items.clear();
        g.step(1 / 120);
      }
      expect(boosted.survival.points, closeTo(plain.survival.points * 3, 1e-8));
      final a = plain.survival.points, b = boosted.survival.points;
      for (final g in [plain, boosted]) {
        g.survival.items.add(
          InfiniteItem(InfiniteItemKind.combo, g.ballX, g.ballY),
        );
        g.step(1 / 120);
      }
      expect(
        boosted.survival.points - b,
        closeTo((plain.survival.points - a) * 3, 1e-8),
      );
      expect(
        (plain.ballX, plain.ballY, plain.velocity),
        (boosted.ballX, boosted.ballY, boosted.velocity),
      );
    },
  );
  test(
    'existing wallet ownership migrates and new platform purchases survive reload',
    () async {
      await SharedPreferencesAsync().setString(
        'gilt.economy.v1',
        '{"wallet":600,"owned":["steel","neon"],"selected":"neon"}',
      );
      final p = PlayerProfile();
      await p.load();
      expect(p.selectedBall, BallCosmetic.neon);
      expect(p.selectedPlatform, PlatformStyle.classic);
      expect(p.selectPlatform(PlatformStyle.solar), true);
      expect(p.wallet, 50);
      expect(p.selectPlatform(PlatformStyle.prism), false);
      p.selectPlatform(PlatformStyle.classic);
      p.selectPlatform(PlatformStyle.solar);
      expect(p.wallet, 50);
      await p.save();
      final loaded = PlayerProfile();
      await loaded.load();
      expect(loaded.selectedPlatform, PlatformStyle.solar);
      expect(loaded.ownedBalls, contains(BallCosmetic.neon));
      expect(loaded.equipmentMultiplier, 2.35);
    },
  );
  for (final mode in [ControlMode.analog, ControlMode.twoFinger]) {
    for (final sensitivity in [0.0, .25, .5, 1.0]) {
      test(
        '$mode sensitivity $sensitivity scales both axes immediately and holds on release',
        () {
          final g = BalanceGame()
            ..setControlMode(mode)
            ..start(gameMode: GameMode.practice);
          g.analogSensitivity = g.twoFingerSensitivity = sensitivity;
          final initial = g.left;
          g.grabPivot(0);
          g.grabPivot(1);
          g.dragPivot(0, -40);
          g.dragPivot(1, -20);
          g.step(1 / 120);
          expect(g.left, closeTo(initial - 40 * sensitivity, 1e-7));
          expect(g.right, closeTo(initial - 20 * sensitivity, 1e-7));
          g.releasePivot(0);
          g.releasePivot(1);
          g.step(.1);
          expect(g.left, closeTo(initial - 40 * sensitivity, 1e-7));
        },
      );
    }
  }
  test(
    'sensitivity preferences default to full response and persist independently',
    () async {
      final p = PlayerProfile();
      await p.load();
      expect(p.analogSensitivity, 1);
      expect(p.twoFingerSensitivity, 1);
      p.analogSensitivity = .35;
      p.twoFingerSensitivity = .8;
      await p.save();
      final restored = PlayerProfile();
      await restored.load();
      expect(restored.analogSensitivity, .35);
      expect(restored.twoFingerSensitivity, .8);
    },
  );
  testWidgets(
    'control cards explain and select modes; sliders fit a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: p));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ControlOptions), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<ControlMode>), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('control-analog')));
      await tester.tap(find.byKey(const ValueKey('control-analog')));
      await tester.pump();
      expect(p.controlMode, ControlMode.analog);
      await tester.ensureVisible(
        find.byKey(const ValueKey('analog-sensitivity')),
      );
      await tester.pump();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('analog-sensitivity')),
      );
      slider.onChanged!(.4);
      slider.onChangeEnd!(.4);
      await tester.pump();
      expect(p.analogSensitivity, .4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'shop platform tab equips a paid rail and shows its added points',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = PlayerProfile()..wallet = 200;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BallShop(profile: p)),
        ),
      );
      await tester.tap(find.text('Platforms'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-platform-copper')).hitTestable(),
        140,
      );
      await tester.tap(find.byKey(const ValueKey('buy-platform-copper')));
      await tester.pump();
      expect(p.selectedPlatform, PlatformStyle.copper);
      expect(p.wallet, 120);
      expect(p.equipmentMultiplier, 1.25);
      expect(tester.takeException(), isNull);
      await p.saveEconomy();
    },
  );
}
