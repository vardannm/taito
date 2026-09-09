import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/game.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render proportional gameplay on phone and desktop', (
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
    final profile = PlayerProfile()
      ..sound = false
      ..haptics = false;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ArcadeApp(profile: profile),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      await tester.runAsync(() => saveImage(image, 'artifacts/$name.png'));
    }

    await capture('tutorial-controls');
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await capture('tutorial-classic');
    await tester.tap(find.text('NEXT'));
    await tester.pump();
    await capture('tutorial-infinite');
    await tester.tap(find.text("LET'S PLAY"));
    await tester.pump();
    await capture('drag-home');
    await tester.tap(find.text('CLASSIC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('classic-levels');
    await tester.tap(find.text('First steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('drag-game');
    final classic = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    classic.setControlMode(ControlMode.oneFinger);
    classic.start();
    await tester.pump(const Duration(milliseconds: 16));
    await capture('one-finger-classic');
    classic.setControlPosition(.65);
    await tester.pump(const Duration(milliseconds: 16));
    await capture('one-finger-tilted');
    classic.setControlMode(ControlMode.twoFinger);
    tester.view.physicalSize = const Size(1130, 900);
    tester.view.padding = FakeViewPadding();
    await tester.pump();
    await capture('drag-desktop');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 34);
    await tester.pump();
    classic.start(levelNumber:31);
    await tester.pump(const Duration(milliseconds:16));
    await capture('spider-level-31');
    classic.start(levelNumber:50);
    await tester.pump(const Duration(milliseconds:16));
    await capture('spider-level-50');
    classic.spiders.first.chasing=true;
    await tester.pump(const Duration(milliseconds:16));
    await capture('spider-alert');
    classic.start();
    await tester.pump(const Duration(milliseconds:16));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
    await capture('drag-pause');
    await tester.tap(find.text('BACK TO CLUB'));
    await tester.pump();
    await tester.tap(find.text('INFINITE'));
    await tester.pump();
    await capture('ascent-start');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await capture('ascent-moving');
    // Stage each hazard state for visual QA, without claiming a human playthrough.
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    for (final kind in HazardKind.values) {
      final hazard = SpecialHazard(kind, x: 100, y: 260);
      game.specialHazards
        ..clear()
        ..add(hazard);
      game.stallTime = 0;
      hazard.step(1, 0);
      await tester.pump(const Duration(milliseconds: 16));
      await capture('hazard-${kind.name}-warning');
      hazard.step(1.1, 0);
      await tester.pump(const Duration(milliseconds: 16));
      await capture('hazard-${kind.name}-active');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
