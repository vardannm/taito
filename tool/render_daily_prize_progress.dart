import 'dart:io';
import 'dart:ui' as ui;
import 'package:balance_arcade/daily_prize_sheet.dart';
import 'package:balance_arcade/menu_design.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render continuing daily prize days', (tester) async {
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
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory('artifacts/daily-prize-progress').createSync(recursive: true);
    for (final count in [5, 9, 10]) {
      tester.view.physicalSize = const Size(390, 844);
      final p = PlayerProfile()..wallet = 2234;
      p.dailyPrizes.claimed = count;
      p.dailyPrizes.lastClaim = DateTime.now().toUtc().subtract(
        const Duration(days: 1),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: menuBackground,
              body: DailyPrizeSheet(profile: p),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'artifacts/daily-prize-progress/day-${count + 1}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      image.dispose();
      await tester.pumpWidget(const SizedBox());
    }
  });
}
