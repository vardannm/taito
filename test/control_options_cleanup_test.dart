import 'package:balance_arcade/control_options.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/progress_backup.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'legacy settings and backups migrate without losing earned stars or sensitivity',
    () async {
      for (final mode in [
        ControlMode.analog,
        ControlMode.tiltLift,
        ControlMode.boardTilt,
      ]) {
        final old = PlayerProfile()
          ..controlMode = mode
          ..twoFingerSensitivity = .6;
        old.levelRecords[old.recordKey(1, mode)] = const LevelRecord(
          starMask: 7,
        );
        await old.save();
        final loaded = PlayerProfile();
        await loaded.load();
        expect(loaded.controlMode, ControlMode.oneFinger);
        expect(loaded.totalStars, 3);
        expect(loaded.twoFingerSensitivity, .6);
        final restored = PlayerProfile();
        await ProgressBackup.restore(
          restored,
          ProgressBackup.decode(ProgressBackup.encode(old), testEconomy: false),
        );
        expect(restored.controlMode, ControlMode.oneFinger);
        expect(restored.totalStars, 3);
        expect(restored.levelRecord(1, mode).starMask, 7);
      }
    },
  );

  testWidgets(
    'Options offers two controls and one default sensitivity, without Shop',
    (tester) async {
      await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final options = find.byType(BottomSheet);
      expect(find.byType(ControlOptions), findsOneWidget);
      expect(find.byKey(const ValueKey('control-oneFinger')), findsOneWidget);
      expect(find.byKey(const ValueKey('control-twoFinger')), findsOneWidget);
      for (final mode in [
        ControlMode.analog,
        ControlMode.tiltLift,
        ControlMode.boardTilt,
      ]) {
        expect(find.byKey(ValueKey('control-${mode.name}')), findsNothing);
      }
      expect(
        find.descendant(of: options, matching: find.text('Shop')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('analog-sensitivity')), findsNothing);
      final slider = find.byKey(const ValueKey('two-finger-sensitivity'));
      await tester.ensureVisible(slider);
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, 1.0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
