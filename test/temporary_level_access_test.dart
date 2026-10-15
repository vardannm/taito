import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/levels.dart';
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
  test(
    'temporary access opens all valid levels without adding stars',
    () async {
      final p = PlayerProfile(temporaryLevelAccess: true);
      for (var level = 1; level <= ClassicLevels.count; level++) {
        expect(p.selectClassicLevel(level), isTrue);
      }
      expect(p.selectClassicLevel(0), isFalse);
      expect(p.selectClassicLevel(ClassicLevels.count + 1), isFalse);
      expect(p.totalStars, 0);
      expect(p.levelRecords, isEmpty);
      await p.save();
      final normal = PlayerProfile(temporaryLevelAccess: false);
      await normal.load();
      expect(normal.totalStars, 0);
      expect(normal.isClassicLevelUnlocked(80), isFalse);
      expect(normal.isClassicLevelUnlocked(1), isTrue);
    },
  );

  for (final mode in ControlMode.values) {
    testWidgets(
      'level picker launches level 80 with $mode and keeps it on retry',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final profile = PlayerProfile(temporaryLevelAccess: true)
          ..tutorialSeen = true
          ..sound = false
          ..music = false
          ..haptics = false;
        await tester.pumpWidget(ArcadeApp(profile: profile));
        await tester.pump();
        await openClassicLevels(tester);
        final option = find.byKey(ValueKey('level-control-${mode.name}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump();
        expect(profile.controlMode, mode);
        final level = find.byKey(const ValueKey('level-80'));
        await tester.scrollUntilVisible(
          level,
          500,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.ensureVisible(level);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<InkWell>(level).onTap, isNotNull);
        await tester.tap(level);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
        expect(game.level, 80);
        expect(game.controlMode, mode);
        expect(profile.totalStars, 0);
        final dynamic state = tester.state(find.byType(GameScreen));
        state.start(GameMode.classic);
        await tester.pump();
        expect(game.level, 80);
        expect(game.controlMode, mode);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
