import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  for (final size in [
    const Size(390, 844), // Phone / folded cover screen.
    const Size(844, 390), // Rotating a phone does not make it a tablet.
    const Size(599, 900), // Compact split-screen window.
    const Size(600, 900), // Tablet threshold.
    const Size(820, 1180), // Tablet.
    const Size(740, 800), // Unfolded book-style foldable.
  ]) {
    testWidgets('fresh install selects and saves controls for $size', (
      tester,
    ) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile();
      await profile.load();
      profile.sound = profile.music = profile.haptics = false;
      final expected = size.shortestSide >= 600
          ? ControlMode.twoFinger
          : ControlMode.oneFinger;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      expect(profile.controlMode, expected);
      expect(game.controlMode, expected);
      expect(game.waitingForInput, isTrue);
      await tester.pump();
      await tester.runAsync(() async {
        final reloaded = PlayerProfile();
        await reloaded.load();
        reloaded.applyInitialControlDefault(
          shortestSide: expected == ControlMode.oneFinger ? 820 : 390,
        );
        expect(reloaded.controlMode, expected);
      });

      // Folding/unfolding during play preserves the controls and active input.
      game.beginInput();
      game.grabPivot(0);
      game.dragPivot(0, -10);
      final epoch = game.inputEpoch;
      final target = game.pivotTargets[0];
      tester.view.physicalSize = expected == ControlMode.oneFinger
          ? const Size(1640, 2360)
          : const Size(780, 1688);
      await tester.pump();
      expect(game.controlMode, expected);
      expect(game.inputEpoch, epoch);
      expect(game.pivotTargets[0], target);
    });
  }

  test(
    'saved modern and legacy control preferences override screen size',
    () async {
      final storage = SharedPreferencesAsync();
      for (final mode in [ControlMode.oneFinger, ControlMode.twoFinger]) {
        await storage.setString('gilt.controlMode', mode.name);
        final profile = PlayerProfile();
        await profile.load();
        expect(profile.applyInitialControlDefault(shortestSide: 820), isFalse);
        expect(profile.controlMode, mode);
      }
      await storage.remove('gilt.controlMode');
      for (final oneFinger in [true, false]) {
        await storage.setBool('gilt.oneFinger', oneFinger);
        final profile = PlayerProfile();
        await profile.load();
        expect(profile.applyInitialControlDefault(shortestSide: 820), isFalse);
        expect(
          profile.controlMode,
          oneFinger ? ControlMode.oneFinger : ControlMode.twoFinger,
        );
      }
    },
  );

  test(
    'waits for a usable size and respects an explicit choice before sizing',
    () async {
      final profile = PlayerProfile();
      await profile.load();
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          profile.applyInitialControlDefault(shortestSide: invalid),
          isFalse,
        );
      }
      expect(profile.applyInitialControlDefault(shortestSide: 820), isTrue);
      expect(profile.controlMode, ControlMode.twoFinger);

      final manual = PlayerProfile();
      await manual.load();
      manual.controlMode = ControlMode.oneFinger;
      expect(manual.applyInitialControlDefault(shortestSide: 820), isFalse);
      expect(manual.controlMode, ControlMode.oneFinger);
    },
  );
}
