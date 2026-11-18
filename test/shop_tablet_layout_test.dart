import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final size in [
    const Size(768, 1024),
    const Size(820, 1180),
    const Size(1024, 1366),
    const Size(1366, 1024),
    const Size(390, 844),
  ]) {
    testWidgets('shop uses the available space at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..wallet = 300001;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BallShop(profile: profile)),
        ),
      );
      final ball = tester.getRect(find.byKey(const ValueKey('ball-showcase')));
      final platform = tester.getRect(
        find.byKey(const ValueKey('platform-showcase')),
      );
      final portraitTablet = size.width >= 600 && size.height > size.width;
      if (portraitTablet) {
        expect(platform.top, greaterThan(ball.bottom));
        expect(
          tester.getSize(find.byKey(const ValueKey('ball-pages'))).height,
          greaterThanOrEqualTo(260),
        );
        // The loadout reaches the bottom of the viewport, rather than ending
        // halfway down the tablet. Smaller iPads can scroll to purchases.
        final footer = tester.getRect(find.byKey(const ValueKey('gear-total')));
        expect(footer.bottom, greaterThan(size.height * .9));
        if (size.height >= 1180) {
          expect(footer.bottom, lessThanOrEqualTo(size.height));
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('upgrade-hearts')),
        );
        expect(
          find.byKey(const ValueKey('upgrade-hearts')).hitTestable(),
          findsOneWidget,
        );
      } else if (size.width >= 760) {
        expect(platform.left, greaterThan(ball.right));
        expect(platform.top, closeTo(ball.top, 1));
      } else {
        expect(platform.top, greaterThan(ball.bottom));
        expect(
          tester.getSize(find.byKey(const ValueKey('ball-pages'))).height,
          150,
        );
      }
      await tester.ensureVisible(find.byKey(const ValueKey('next-ball')));
      await tester.tap(find.byKey(const ValueKey('next-ball')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('buy-coral')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('tablet shop scrolls at large accessibility text sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(768, 1024);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: BallShop(profile: PlayerProfile()..tutorialSeen = true),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('upgrade-hearts')));
    expect(
      find.byKey(const ValueKey('upgrade-hearts')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
