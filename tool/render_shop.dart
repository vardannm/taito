import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/profile.dart';

void main() {
  testWidgets('render shop catalog, purchase and responsive layouts', (
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
    Directory('artifacts/shop').createSync(recursive: true);
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/shop/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    for (final (name, size, scale) in [
      ('phone', const Size(390, 844), 1.0),
      ('small-large-text', const Size(320, 568), 1.8),
      ('tablet', const Size(820, 1180), 1.0),
      ('desktop', const Size(1440, 900), 1.0),
      ('landscape', const Size(844, 390), 1.0),
    ]) {
      tester.view.physicalSize = size;
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..haptics = false
        ..wallet = 1250;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(body: BallShop(profile: profile)),
          ),
        ),
      );
      await tester.pump();
      await capture('$name-catalog');
      await tester.ensureVisible(find.text('Explore world'));
      await tester.pump();
      await tester.tap(find.text('Explore world'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('$name-details');
      await tester.tap(find.byKey(const ValueKey('confirm-shop-purchase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('$name-success');
      await tester.tap(find.byKey(const ValueKey('confirm-shop-purchase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Upgrades'));
      await tester.pump();
      await capture('$name-upgrades');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
