import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/infinite_painter.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'start_flow_test.dart' show launch, contact;
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'audio preferences migrate muted users and persist independently',
    () async {
      await SharedPreferencesAsync().setBool('gilt.sound', false);
      final profile = PlayerProfile();
      await profile.load();
      expect((profile.sound, profile.music), (false, false));
      for (final pair in [
        (false, true),
        (true, false),
        (true, true),
        (false, false),
      ]) {
        profile.sound = pair.$1;
        profile.music = pair.$2;
        await profile.save();
        final restored = PlayerProfile();
        await restored.load();
        expect((restored.sound, restored.music), pair);
      }
    },
  );
  test(
    'pacing is slower early, smooth throughout and retains the extreme ceiling',
    () {
      final game = BalanceGame()..start(gameMode: GameMode.infinite);
      var previous = game.ascentSpeed;
      for (var metres = 1; metres <= 5000; metres++) {
        game.maxHeight = metres * 10.0;
        // The smoothstep slope peaks at 1.5; allow the configured growth.
        final maxStep =
            112 * InfiniteDifficulty.speedGrowth * 1.5 / 2400 +
            9 * InfiniteDifficulty.paceGrowth / 600;
        expect(
          game.ascentSpeed,
          inInclusiveRange(previous, previous + maxStep + 1e-6),
        );
        previous = game.ascentSpeed;
      }
      expect(
        previous,
        68 +
            112 * InfiniteDifficulty.speedGrowth +
            36 * InfiniteDifficulty.paceGrowth,
      );
      expect(InfiniteTuning.difficultyAt(900), lessThan(.35));
      expect(InfiniteTuning.difficultyAt(2400), 1);
      expect(InfiniteTuning.runDensity(1000000, 0), 0);
      expect(InfiniteTuning.runDensity(1000000, 600), lessThan(.2));
      expect(InfiniteTuning.runDensity(60000, 2400), 1);
      expect(InfiniteTuning.complexityAt(2400), 0);
      expect(InfiniteTuning.complexityAt(4200), 1);
      expect(InfiniteTuning.startingPace(999999), 1);
    },
  );
  test(
    'all ten combo tiers have distinct colors and the cyan-to-gold transition is continuous',
    () {
      expect({for (var i = 0; i < 10; i++) comboColor(i / 9)}, hasLength(10));
      final below = comboEnergyColor(8 / 9 - .00001),
          above = comboEnergyColor(8 / 9 + .00001);
      expect((below.r - above.r).abs(), lessThan(.001));
      expect((below.g - above.g).abs(), lessThan(.001));
      expect((below.b - above.b).abs(), lessThan(.001));
    },
  );
  testWidgets(
    'level chooser is centered inside the preview and run HUD uses the reclaimed header space',
    (tester) async {
      final game = await launch(tester, ControlMode.twoFinger);
      for (final mode in [1, 2]) {
        await selectWorld(tester, mode);
        final board = tester.getRect(find.byType(PivotBoard));
        final button = tester.getRect(
          find.byKey(const ValueKey('choose-level')),
        );
        expect(board.contains(button.center), true);
        expect(button.center.dx, closeTo(board.center.dx, 1));
        expect(find.byKey(const ValueKey('board-level-name')), findsOneWidget);
        expect(game.waitingForInput, true);
      }
      await selectWorld(tester, 0);
      final before = tester.getRect(find.byType(PivotBoard));
      await tester.tapAt(contact(tester, game));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final board = tester.getRect(find.byType(PivotBoard));
      expect(board.top, 0);
      expect(board.height, greaterThan(before.height + 80));
      final pause = find.byKey(const ValueKey('board-pause'));
      expect(board.contains(tester.getCenter(pause)), true);
      expect(
        board.contains(
          tester.getCenter(find.byKey(const ValueKey('board-hud'))),
        ),
        true,
      );
      await tester.tap(pause);
      expect(game.paused, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('shop includes cabinets and new premium gear persists', (
    tester,
  ) async {
    final profile = PlayerProfile()..wallet = 10000;
    expect(BallCosmetic.values.length, 19);
    expect(PlatformStyle.values.length, 12);
    expect(profile.selectBall(BallCosmetic.singularity), true);
    expect(profile.selectPlatform(PlatformStyle.sovereign), true);
    await profile.save();
    final restored = PlayerProfile();
    await restored.load();
    expect(restored.selectedBall, BallCosmetic.singularity);
    expect(restored.selectedPlatform, PlatformStyle.sovereign);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BallShop(profile: restored)),
      ),
    );
    await tester.tap(find.text('Cabinet Styles'));
    await tester.pump();
    expect(find.byKey(const ValueKey('cabinet-brass')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
