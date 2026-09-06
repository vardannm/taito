import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/tutorial.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('tutorial completion persists across fresh profiles', () async {
    final first = PlayerProfile();
    await first.load();
    expect(first.tutorialSeen, isFalse);
    await first.completeTutorial();
    final second = PlayerProfile();
    await second.load();
    expect(second.tutorialSeen, isTrue);
    expect(second.runs, 0);
    expect(second.infiniteRuns, 0);
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets(
      'first-launch tutorial completes and stays dismissed at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.reset);
        final profile = PlayerProfile()
          ..sound = false
          ..haptics = false;
        await tester.pumpWidget(ArcadeApp(profile: profile));
        expect(find.byType(FirstPlayTutorial), findsOneWidget);
        expect(find.byType(PivotBoard), findsNothing);
        for (var i = 0; i < 2; i++) {
          await tester.ensureVisible(find.text('NEXT'));
          await tester.tap(find.text('NEXT'));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.text("LET'S PLAY"));
        await tester.tap(find.text("LET'S PLAY"));
        await tester.pump();
        expect(profile.tutorialSeen, isTrue);
        expect(find.byType(FirstPlayTutorial), findsNothing);
        expect(profile.runs, 0);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(ArcadeApp(profile: profile));
        expect(find.byType(FirstPlayTutorial), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('skip is remembered and How to Play can replay the tutorial', (
    tester,
  ) async {
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    expect(profile.tutorialSeen, isTrue);
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('REPLAY QUICK TUTORIAL'));
    await tester.tap(find.text('REPLAY QUICK TUTORIAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FirstPlayTutorial), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await tester.tap(find.text('BACK'));
    await tester.pump();
    expect(find.text('Two fingers. One platform.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
