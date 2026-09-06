import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(430, 932),
  ]) {
    testWidgets('home, guide and gameplay fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = PlayerProfile()
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(ArcadeApp(profile: profile));
      expect(find.text('A little tilt.\nA lot of nerve.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('HOW TO PLAY'));
      await tester.tap(find.text('HOW TO PLAY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('A game of balance.'), findsOneWidget);
      await tester.ensureVisible(find.text('TRY PRACTICE'));
      await tester.pump();
      await tester.tap(find.text('TRY PRACTICE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PRACTICE'), findsOneWidget);
      expect(find.byType(ThumbRocker), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('two thumbs can independently hold and release rocker controls', (
    tester,
  ) async {
    final values = [0.0, 0.0];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ThumbRocker(
                label: 'LEFT',
                enabled: true,
                onChanged: (v) => values[0] = v,
              ),
              ThumbRocker(
                label: 'RIGHT',
                enabled: true,
                onChanged: (v) => values[1] = v,
              ),
            ],
          ),
        ),
      ),
    );
    final a = tester.getTopLeft(find.byType(ThumbRocker).first);
    final b = tester.getTopLeft(find.byType(ThumbRocker).last);
    final left = await tester.startGesture(
      a + const Offset(40, 20),
      pointer: 1,
    );
    final right = await tester.startGesture(
      b + const Offset(40, 20),
      pointer: 2,
    );
    expect(values, [-1, -1]);
    await left.moveTo(a + const Offset(40, 90));
    expect(values, [1, -1]);
    await left.up();
    expect(values, [0, -1]);
    await right.cancel();
    expect(values, [0, 0]);
    expect(tester.takeException(), isNull);
  });
}
