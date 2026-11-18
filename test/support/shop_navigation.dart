import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> browseShop(WidgetTester tester, String kind, int index) async {
  final pages = find.byKey(ValueKey('$kind-pages'));
  final controller = tester.widget<PageView>(pages).controller!;
  while (controller.page!.round() != index) {
    final direction = controller.page!.round() < index ? 'next' : 'previous';
    final arrow = find.byKey(ValueKey('$direction-$kind'));
    await tester.ensureVisible(arrow);
    await tester.tap(arrow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> revealShopBall(WidgetTester tester, BallCosmetic ball) async {
  await browseShop(tester, 'ball', ballShopOrder.indexOf(ball));
  await tester.ensureVisible(find.byKey(ValueKey('buy-${ball.name}')));
  await tester.pump();
}

Future<void> revealShopPlatform(
  WidgetTester tester,
  PlatformStyle style,
) async {
  await browseShop(tester, 'platform', platformShopOrder.indexOf(style));
  await tester.ensureVisible(
    find.byKey(ValueKey('buy-platform-${style.name}')),
  );
  await tester.pump();
}
