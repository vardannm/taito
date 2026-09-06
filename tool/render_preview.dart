import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/board_painter.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('export real Flutter screens and procedural brand icons', (
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

    await capture('gilt-home');
    await tester.tap(find.text('CLASSIC'));
    await tester.pump(const Duration(milliseconds: 100));
    await capture('gilt-game');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));
    await capture('gilt-pause');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());

    await tester.runAsync(() async {
      Future<void> icon(int size, String path) async {
        final recording = ui.PictureRecorder();
        final canvas = Canvas(recording);
        canvas.scale(size / 1024);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          Paint()..color = ink,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(100, 100, 824, 824),
            const Radius.circular(170),
          ),
          Paint()
            ..color = brass
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9,
        );
        canvas.drawCircle(const Offset(512, 440), 195, Paint()..color = brass);
        canvas.drawCircle(const Offset(512, 440), 156, Paint()..color = ink);
        canvas.drawCircle(
          const Offset(512, 440),
          103,
          Paint()..color = const Color(0xFF0E2929),
        );
        canvas.drawLine(
          const Offset(238, 728),
          const Offset(795, 615),
          Paint()
            ..color = cream
            ..strokeWidth = 24
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(238, 738),
          const Offset(795, 625),
          Paint()
            ..color = const Color(0xFF788F88)
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        const p = Offset(624, 603);
        canvas.drawCircle(
          p,
          54,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-.4, -.5),
              colors: [Colors.white, Color(0xFFDCE1D5), Color(0xFF4B6864)],
            ).createShader(Rect.fromCircle(center: p, radius: 54)),
        );
        final picture = recording.endRecording();
        final image = await picture.toImage(size, size);
        await saveImage(image, path);
        picture.dispose();
      }

      final contents = jsonDecode(
        File(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
        ).readAsStringSync(),
      );
      for (final entry in contents['images']) {
        final size =
            double.parse((entry['size'] as String).split('x').first) *
            double.parse((entry['scale'] as String).replaceAll('x', ''));
        await icon(
          size.round(),
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry['filename']}',
        );
      }
      for (final size in [192, 512]) {
        await icon(size, 'web/icons/Icon-$size.png');
        await icon(size, 'web/icons/Icon-maskable-$size.png');
      }
      await icon(64, 'web/favicon.png');
      await icon(1024, 'artifacts/gilt-icon.png');
    });
  });
}
