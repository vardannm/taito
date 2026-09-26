import '../test/support/mode_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render vertical analog controls on two phone sizes', (
    tester,
  ) async {
    for (final family in ['sans-serif', 'monospace', 'Roboto']) {
      final loader = FontLoader(family);
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..haptics = false;
    profile.controlMode = ControlMode.analog;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ArcadeApp(profile: profile),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await openClassicLevels(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('First steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final a = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('analog-left'))),
      pointer: 1,
    );
    final b = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('analog-right'))),
      pointer: 2,
    );
    await a.moveBy(const Offset(0, -30));
    await b.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 50));
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    await tester.runAsync(() => saveImage(image, 'artifacts/analog-phone.png'));
    await a.up();
    await b.up();
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump(const Duration(milliseconds: 50));
    final small = await render.toImage(pixelRatio: 2);
    await tester.runAsync(
      () => saveImage(small, 'artifacts/analog-small-phone.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
