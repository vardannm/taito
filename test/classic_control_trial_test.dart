import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'support/mode_navigation.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets(
    'Classic uses the selected control through settings and retries',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..haptics = false
        ..controlMode = ControlMode.oneFinger;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
      final dynamic state = tester.state(find.byType(GameScreen));
      await selectWorld(tester, 1);
      expect(game.controlMode, ControlMode.oneFinger);
      expect(find.byKey(const ValueKey('tilt-lift-tilt')), findsNothing);
      expect(profile.controlMode, ControlMode.oneFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(
        find.byKey(const ValueKey('control-twoFinger')),
      );
      await tester.tap(find.byKey(const ValueKey('control-twoFinger')));
      await tester.pump();
      expect(profile.controlMode, ControlMode.twoFinger);
      expect(game.controlMode, ControlMode.twoFinger);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('control-twoFinger'))),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      state.start(GameMode.classic);
      await tester.pump();
      expect(game.controlMode, ControlMode.twoFinger);
      state.start(GameMode.classic); // Retry / next-level launch path.
      await tester.pump();
      expect(game.controlMode, ControlMode.twoFinger);
      state.start(GameMode.merge2048);
      await tester.pump();
      expect(game.controlMode, ControlMode.twoFinger);
      state.start(GameMode.infinite);
      await tester.pump();
      expect(game.controlMode, ControlMode.twoFinger);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
