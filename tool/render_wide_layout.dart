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

import '../test/support/mode_navigation.dart';

void main() {
  testWidgets('render responsive menu, board and Settings', (tester) async {
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
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
    final key = GlobalKey();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/wide-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
    }

    for (final (name, size) in [
      ('phone', const Size(390, 844)),
      ('duo-closed', const Size(540, 720)),
      ('duo-expanded', const Size(1114, 720)),
      ('tablet', const Size(820, 1180)),
      ('desktop', const Size(1440, 900)),
      ('short-desktop', const Size(1024, 500)),
    ]) {
      tester.view.physicalSize = size;
      final profile = PlayerProfile()
        ..tutorialSeen = true
        ..music = false
        ..sound = false
        ..haptics = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ArcadeApp(profile: profile),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await capture('$name-menu');
      await selectWorld(tester, 1);
      await startWorld(tester);
      await tester.pump(const Duration(milliseconds: 600));
      await capture('$name-classic');
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await capture('$name-pause');
      final dynamic state = tester.state(find.byType(GameScreen));
      state.home();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await capture('$name-settings');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
