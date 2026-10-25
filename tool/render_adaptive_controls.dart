import 'dart:io';
import 'dart:ui' as ui;

import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('render folded Duo, expanded Duo and tablet control choices', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'Roboto', 'MaterialIcons']) {
      final loader = FontLoader(family);
      loader.addFont(
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
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    for (final (name, size) in [
      ('duo-closed', const Size(540, 720)),
      ('duo-expanded', const Size(1114, 720)),
      ('tablet', const Size(820, 1180)),
    ]) {
      tester.view.physicalSize = size;
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..sound = false
        ..music = false
        ..haptics = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('CHOOSE YOUR CONTROLS'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/controls-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      await tester.pumpWidget(const SizedBox());
    }
  });
}
