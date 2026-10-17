import 'package:balance_arcade/boot_splash.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget gate({bool reducedMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: const GiltIntroGate(child: Text('menu')),
    ),
  ),
);

void main() {
  testWidgets('the intro covers the app, then hands it over', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(gate());
    expect(find.byType(GiltIntro), findsOneWidget);
    // Nothing is written on screen; the intro still names itself to screen readers.
    expect(find.bySemanticsLabel('GILT'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(GiltIntro), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(GiltIntro), findsNothing);
    expect(find.text('menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a tap skips to the fade', (tester) async {
    await tester.pumpWidget(gate());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(GiltIntro));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(GiltIntro), findsNothing);
  });

  testWidgets('reduced motion keeps it brief', (tester) async {
    await tester.pumpWidget(gate(reducedMotion: true));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(GiltIntro), findsNothing);
    expect(find.text('menu'), findsOneWidget);
  });

  testWidgets('the menu pumps without an intro by default', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(ArcadeApp(profile: profile));
    expect(find.byType(GiltIntro), findsNothing);
  });
}
