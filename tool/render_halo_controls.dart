import 'dart:io';
import 'dart:ui' as ui;
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/one_finger_controls.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../test/support/mode_navigation.dart' show startWorld;

void main() {
  testWidgets('render actual floating Halo in idle and two touch positions', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    for (final family in [
      'sans-serif',
      'Roboto',
      'monospace',
      'MaterialIcons',
    ]) {
      final fontFile = family == 'MaterialIcons'
          ? 'materialicons-regular.otf'
          : 'roboto-regular.ttf';
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/$fontFile',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: 44, bottom: 24);
    addTearDown(tester.view.reset);
    final profile = PlayerProfile()
      ..tutorialSeen = true
      ..sound = false
      ..music = false
      ..haptics = false
      ..haloJoystick = true;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ArcadeApp(profile: profile),
      ),
    );
    await tester.pump();
    await startWorld(tester);
    await tester.pump(const Duration(milliseconds: 650));
    final dynamic state = tester.state(find.byType(GameScreen));
    state.ticker.stop();
    final images = <ui.Image>[];
    Future<void> capture(String name) async {
      await tester.pump();
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      images.add(image);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('artifacts/halo-$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    await capture('idle');
    final control = find.byType(OneFingerControls),
        rect = tester.getRect(control);
    var finger = await tester.startGesture(
      rect.topLeft + Offset(rect.width * .25, rect.height * .45),
    );
    await finger.moveBy(const Offset(16, -12));
    await capture('touch-left');
    await finger.up();
    await tester.pump();
    finger = await tester.startGesture(
      rect.topLeft + Offset(rect.width * .72, rect.height * .68),
    );
    await finger.moveBy(const Offset(-14, 9));
    await capture('touch-right');
    await finger.up();
    await tester.pump();
    final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF10282D), BlendMode.src);
    const names = ['NO TOUCH', 'TOUCH ON LEFT', 'TOUCH ON RIGHT'];
    for (var i = 0; i < images.length; i++) {
      final label = TextPainter(
        text: TextSpan(
          text: names[i],
          style: const TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 15,
            color: Color(0xFFE9C47C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(i * 406.0 + 16, 12));
      canvas.drawImage(images[i], Offset(i * 406.0, 40), Paint());
      label.dispose();
    }
    final picture = recorder.endRecording(),
        sheet = await picture.toImage(1202, 884);
    await tester.runAsync(() async {
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/halo-floating-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    for (final image in images) {
      image.dispose();
    }
    sheet.dispose();
    picture.dispose();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
