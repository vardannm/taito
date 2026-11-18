import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../test/support/mode_navigation.dart';

void main() {
  testWidgets('inspect menus at phone sizes and with enlarged text', (
    tester,
  ) async {
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/${family == 'MaterialIcons' ? 'materialicons-regular.otf' : 'roboto-regular.ttf'}',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final key = GlobalKey();
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/menu-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    for (final variant in ['390', '320', 'large-390', 'large-320']) {
      final size = variant.endsWith('320')
          ? const Size(320, 568)
          : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue =
          variant.startsWith('large') ? 1.8 : 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(
            disableAnimations: variant.startsWith('large'),
          );
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false
        ..infiniteBestScore = 148620
        ..mergeBest = 28640
        ..wallet = 12480;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await settle();
      await capture('home-$variant');
      await selectWorld(tester, 2);
      await capture('merge-$variant');
      await selectWorld(tester, 1);
      await capture('classic-$variant');
      await tester.tap(find.byKey(const ValueKey('choose-level')));
      await settle();
      await capture('levels-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byKey(const ValueKey('board-shop')));
      await settle();
      await capture('shop-$variant');
      for (final (name, key) in [
        ('platforms', 'platform-showcase'),
        ('upgrades', 'shop-upgrades'),
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await settle();
        await capture('$name-$variant');
      }
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Settings'));
      await settle();
      await capture('options-$variant');
      await tester.scrollUntilVisible(
        find.text('Sound Effects'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await settle();
      await capture('options-lower-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Daily prizes'));
      await settle();
      await capture('prizes-$variant');
      profile.dailyPrizes.claimed = 4;
      profile.dailyPrizes.lastClaim = DateTime.now().toUtc().subtract(
        const Duration(days: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(
        find.byKey(const ValueKey('daily-claim-platform')),
      );
      await settle();
      await capture('prizes-day-five-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Modes'));
      await settle();
      await tester.scrollUntilVisible(
        find.text('DAILY'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('DAILY'));
      await settle();
      await capture('daily-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Modes'));
      await settle();
      await tester.scrollUntilVisible(
        find.text('HOW TO PLAY'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('HOW TO PLAY'));
      await settle();
      await capture('guide-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Modes'));
      await settle();
      await capture('arcade-$variant');
      await tester.scrollUntilVisible(
        find.textContaining('ACHIEVEMENTS'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('ACHIEVEMENTS'));
      await settle();
      await capture('achievements-$variant');
      Navigator.of(tester.element(find.byType(GameScreen))).pop();
      await settle();
      await tester.tap(find.byTooltip('Modes'));
      await settle();
      await tester.scrollUntilVisible(
        find.text('Goals, friends & backup'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Goals, friends & backup'));
      await settle();
      await capture('club-$variant');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await settle();
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 260));
      await tester.tap(find.byKey(const ValueKey('board-pause')));
      await settle();
      await capture('pause-$variant');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
