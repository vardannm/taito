import 'package:balance_arcade/level_fireworks.dart';
import 'package:balance_arcade/mastery_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('earned stars land one at a time, each announced once', (
    tester,
  ) async {
    final landed = <(int, Duration)>[];
    var clock = Duration.zero;
    await tester.pumpWidget(
      host(
        StarReveal(
          1 | 2 | 8,
          count: 4,
          onReveal: (i) => landed.add((i, clock)),
        ),
      ),
    );
    expect(find.bySemanticsLabel('3 of 4 stars'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      clock += const Duration(milliseconds: 50);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(landed.map((e) => e.$1), [0, 1, 2]);
    final gaps = [
      for (var i = 1; i < landed.length; i++)
        (landed[i].$2 - landed[i - 1].$2).inMilliseconds,
    ];
    expect(gaps.every((ms) => ms >= 350 && ms <= 400), isTrue, reason: '$gaps');
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(4));
  });

  testWidgets('reduced motion shows every star at once, silently', (
    tester,
  ) async {
    final landed = <int>[];
    await tester.pumpWidget(
      host(StarReveal(7, count: 4, onReveal: landed.add), still: true),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(landed, isEmpty);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
  });

  testWidgets('fireworks play once and settle', (tester) async {
    await tester.pumpWidget(
      host(const SizedBox(width: 360, height: 600, child: LevelFireworks())),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
