import 'dart:convert';

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
    'legacy settings and backups retain stars and use full sensitivity',
    () async {
      for (final mode in [
        ControlMode.analog,
        ControlMode.tiltLift,
        ControlMode.boardTilt,
      ]) {
        final old = PlayerProfile()..controlMode = mode;
        old.levelRecords[old.recordKey(1, mode)] = const LevelRecord(
          starMask: 7,
        );
        await old.save();
        final loaded = PlayerProfile();
        await loaded.load();
        expect(loaded.controlMode, ControlMode.oneFinger);
        expect(loaded.totalStars, 3);
        expect(loaded.twoFingerSensitivity, 1);
        final legacy =
            jsonDecode(ProgressBackup.encode(old)) as Map<String, dynamic>;
        legacy['sensitivity'] = [.35, .6];
        final restored = PlayerProfile();
        await ProgressBackup.restore(
          restored,
          ProgressBackup.decode(jsonEncode(legacy), testEconomy: false),
        );
        expect(restored.controlMode, ControlMode.oneFinger);
        expect(restored.totalStars, 3);
        expect(restored.twoFingerSensitivity, 1);
        expect(restored.analogSensitivity, 1);
        expect(restored.levelRecord(1, mode).starMask, 7);
      }
    },
  );

  testWidgets(
    'Options offers two original controls and Halo without sensitivity controls',
    (tester) async {
      await launch(tester, ControlMode.oneFinger);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final options = find.byType(BottomSheet);
      expect(find.byType(ControlOptions), findsOneWidget);
      expect(find.byKey(const ValueKey('control-oneFinger')), findsOneWidget);
      expect(find.byKey(const ValueKey('control-twoFinger')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('control-haloJoystick')),
        findsOneWidget,
      );
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
      expect(
        find.byKey(const ValueKey('two-finger-sensitivity')),
        findsNothing,
      );
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Settings closes with X or a right swipe while vertical scroll stays open',
    (tester) async {
      await launch(tester, ControlMode.oneFinger);
      Future<void> open() async {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await open();
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
        isFalse,
      );
      final sheet = find.byKey(const ValueKey('settings-sheet'));
      await tester.drag(sheet, const Offset(-180, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheet, findsOneWidget);
      await tester.drag(find.byType(ControlOptions), const Offset(0, -240));
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheet, findsOneWidget);
      expect(find.byTooltip('Close settings').hitTestable(), findsOneWidget);
      await tester.drag(sheet, const Offset(180, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheet, findsNothing);
      await open();
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
