import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';

void main() {
  testWidgets('render floating control held on board', (tester) async {
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final p = PlayerProfile()
      ..tutorialSeen = true
      ..floatingOneFinger = true
      ..sound = false
      ..music = false
      ..haptics = false;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ArcadeApp(profile: p),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final pad = find.byKey(const ValueKey('floating-one-finger'));
    final finger = await tester.startGesture(
      tester.getCenter(pad) + const Offset(80, 40),
    );
    await finger.moveBy(const Offset(20, -20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/floating-control-390.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
    await finger.up();
    await tester.pumpWidget(const SizedBox());
  });
}
