import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/premium_menu.dart';
import 'package:balance_arcade/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;
import 'support/mode_navigation.dart';

void main() {
  testWidgets('road winds between stops and reaches the final level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelPicker(
            selected: 1,
            allLevelsUnlocked: true,
            onSelected: (value) => picked = value,
          ),
        ),
      ),
    );
    expect(find.byType(SliverGrid), findsNothing);
    final firstX = tester.getCenter(find.byKey(const ValueKey('level-1'))).dx;
    final secondX = tester.getCenter(find.byKey(const ValueKey('level-2'))).dx;
    expect(secondX, greaterThan(firstX));
    await tester.tap(find.byKey(const ValueKey('level-2')));
    expect(picked, 2);
    final last = find.byKey(ValueKey('level-${ClassicLevels.count}'));
    await tester.scrollUntilVisible(last, 500, maxScrolls: 80);
    await tester.tap(last);
    expect(picked, ClassicLevels.count);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each mode selects its own stage and smoothly themed backdrop', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await launch(tester, ControlMode.analog);
    for (var index = 0; index < 3; index++) {
      await selectWorld(tester, index);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is MenuBallStage &&
              (w.painter as MenuBallStage).mode ==
                  GameMode.values.firstWhere(
                    (m) =>
                        m ==
                        [
                          GameMode.infinite,
                          GameMode.classic,
                          GameMode.merge2048,
                        ][index],
                  ),
        ),
        findsOneWidget,
      );
      final backdrop =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) =>
                          w is CustomPaint && w.painter is PremiumMenuBackdrop,
                    ),
                  )
                  .painter
              as PremiumMenuBackdrop;
      expect(backdrop.page, closeTo(index.toDouble(), .001));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
