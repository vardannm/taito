import 'dart:io';
import 'dart:ui' as ui;
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/survival_upgrades.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../test/support/shop_navigation.dart';

void main() {
  testWidgets('render redesigned shop at phone and desktop sizes', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'Roboto', 'MaterialIcons']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/${family == 'MaterialIcons' ? 'materialicons-regular.otf' : 'roboto-regular.ttf'}',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory('artifacts/shop-redesign').createSync(recursive: true);
    for (final (name, size, scale) in [
      ('phone', const Size(390, 844), 1.0),
      ('small-phone', const Size(320, 568), 1.0),
      ('large-text', const Size(320, 568), 1.8),
      ('empty-wallet', const Size(390, 844), 1.0),
      ('max-upgrades', const Size(390, 844), 1.0),
      ('premium-large-text', const Size(320, 568), 1.8),
      ('desktop', const Size(1280, 800), 1.0),
    ]) {
      tester.view.physicalSize = size;
      final p = PlayerProfile()
        ..tutorialSeen = true
        ..wallet = 2234;
      p.survivalUpgrades[SurvivalUpgrade.magnet] = 2;
      p.survivalUpgrades[SurvivalUpgrade.shield] = 1;
      if (name == 'empty-wallet') p.wallet = 0;
      if (name == 'max-upgrades') {
        for (final upgrade in SurvivalUpgrade.values) {
          p.survivalUpgrades[upgrade] = upgrade.maxLevel;
        }
      }
      if (name == 'premium-large-text') p.wallet = 5999;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(body: BallShop(profile: p)),
          ),
        ),
      );
      await tester.pump();
      await browseShop(
        tester,
        'ball',
        ballShopOrder.indexOf(
          name == 'premium-large-text'
              ? BallCosmetic.aether
              : BallCosmetic.neon,
        ),
      );
      await browseShop(
        tester,
        'platform',
        platformShopOrder.indexOf(
          name == 'premium-large-text'
              ? PlatformStyle.aether
              : PlatformStyle.jade,
        ),
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('shop-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(0);
      await tester.pump();
      Future<void> capture(String suffix) async {
        expect(tester.takeException(), isNull);
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'artifacts/shop-redesign/$name$suffix.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }

      await capture('');
      if (scroll.position.maxScrollExtent > 0) {
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        await capture('-upgrades');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
