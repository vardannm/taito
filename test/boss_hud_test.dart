import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/onboarding.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> frames(WidgetTester tester, [int count = 25]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

double hudOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('infinite-score')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets('a boss hides score, combo and coins until it leaves', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = PlayerProfile()
      ..sound = false
      ..music = false
      ..haptics = false
      ..tutorialSeen = true
      ..tutorial = TutorialProgress(step: TutorialStep.completed);
    await tester.pumpWidget(ArcadeApp(profile: p));
    await frames(tester, 40);
    await tester.tap(find.byKey(const ValueKey('menu-play')).hitTestable());
    await frames(tester, 40);
    await tester.tap(find.byType(OneFingerControls));
    await frames(tester, 5);
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    expect(game.infinite, isTrue);
    expect(hudOpacity(tester), 1);

    game.boss = InfiniteBoss(top: game.visibleTop);
    await frames(tester, 5);
    expect(hudOpacity(tester), 0);
    // Hearts and pause stay available during the fight.
    expect(find.byKey(const ValueKey('board-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('board-hearts')), findsOneWidget);

    game.boss = null;
    await frames(tester, 5);
    expect(hudOpacity(tester), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
