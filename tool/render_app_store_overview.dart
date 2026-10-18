import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'render_app_store.dart' as store;

void main() {
  testWidgets('render compact review sheets for every store display set', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader('sans-serif')..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
      for (final device in store.devices) {
        const cardWidth = 300.0, gutter = 24.0, margin = 30.0;
        final cardHeight = cardWidth * device.height / device.width;
        final width = (margin * 2 + cardWidth * 3 + gutter * 2).round();
        final height = (110 + cardHeight * 2 + gutter + margin).round();
        final recorder = ui.PictureRecorder();
        final drawing = Canvas(recorder);
        drawing.drawColor(const Color(0xff081519), BlendMode.src);
        final title = TextPainter(
          text: TextSpan(
            text:
                'ROLLRISE  /  ${device.id}  /  ${device.width} × ${device.height}',
            style: const TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 23,
              color: Color(0xffe9c47c),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(drawing, const Offset(margin, 35));
        final decoded = <ui.Image>[];
        for (var index = 0; index < store.shots.length; index++) {
          final bytes = File(
            '${store.outputRoot}/screenshots/${device.id}/${store.shots[index].id}.png',
          ).readAsBytesSync();
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: cardWidth.round(),
          );
          final frame = await codec.getNextFrame();
          drawing.drawImageRect(
            frame.image,
            Rect.fromLTWH(
              0,
              0,
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            ),
            Rect.fromLTWH(
              margin + index % 3 * (cardWidth + gutter),
              90 + index ~/ 3 * (cardHeight + gutter),
              cardWidth,
              cardHeight,
            ),
            Paint()..filterQuality = FilterQuality.high,
          );
          decoded.add(frame.image);
          codec.dispose();
        }
        final picture = recorder.endRecording(),
            image = await picture.toImage(width, height);
        await store.saveRgb(
          image,
          '${store.outputRoot}/previews/${device.id}.png',
        );
        for (final thumbnail in decoded) {
          thumbnail.dispose();
        }
        title.dispose();
        image.dispose();
        picture.dispose();
      }
    });
  });
}
