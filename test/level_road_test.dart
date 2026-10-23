import 'package:balance_arcade/level_picker.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/premium_menu.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:balance_arcade/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'start_flow_test.dart' show launch;
import 'support/mode_navigation.dart';

void main() {
  for (final (stars, last) in [
    (0, 4),
    (18, 13),
    (60, 34),
    (156, 80),
    (240, 80),
  ]) {
    testWidgets(
      'road keeps previous levels and at most three ahead at $stars stars',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LevelPicker(
                selected: (stars ~/ 2 + 1).clamp(1, ClassicLevels.count),
                totalStars: stars,
                onSelected: (_) {},
              ),
            ),
          ),
        );
        final road = tester.widget<SliverFixedExtentList>(
          find.byType(SliverFixedExtentList),
        );
        expect(road.delegate.estimatedChildCount, last);
        expect(find.byKey(const ValueKey('level-1')), findsOneWidget);
        final scrollable = find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('level-$last')),
          500,
          scrollable: scrollable,
          maxScrolls: 100,
        );
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('level-${last + 1}')), findsNothing);
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.pixels, closeTo(position.maxScrollExtent, 1));
        expect(find.textContaining('31–50'), findsNothing);
        expect(find.textContaining('51–80'), findsNothing);
        expect(find.textContaining('80 levels'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('road opens at the last won level, not at level 1', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelPicker(
            selected: 21,
            totalStars: 40,
            records: {
              for (var n = 1; n <= 20; n++)
                n: const LevelRecord(starMask: 1),
            },
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final won = tester.getCenter(find.byKey(const ValueKey('level-20')));
    final next = tester.getCenter(find.byKey(const ValueKey('level-21')));
    expect(won.dy, inInclusiveRange(200, 422));
    expect(next.dy, inInclusiveRange(422, 700));
    expect(find.byKey(const ValueKey('level-1')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
    await Scrollable.ensureVisible(tester.element(last), alignment: .5);
    await tester.pumpAndSettle();
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
