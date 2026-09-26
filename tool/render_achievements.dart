import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/achievement_sheet.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/profile.dart';

void main() {
  testWidgets('render achievement sheet', (tester) async {
    for (final family in ['Roboto', 'MaterialIcons']) {
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
      ..infiniteRuns = 4
      ..infiniteBest = 750;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: ink),
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: cream,
            body: AchievementSheet(profile: p),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/achievements-390.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
    image.dispose();
  });
}
