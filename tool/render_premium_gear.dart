import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/ball_world.dart';
import 'package:balance_arcade/ball_painter.dart';
import 'package:balance_arcade/platforms.dart';
import 'package:balance_arcade/platform_painter.dart';
import 'package:balance_arcade/ball_shop.dart';
import 'package:balance_arcade/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:flutter/rendering.dart';
import '../test/support/shop_navigation.dart';

void main() {
  testWidgets('render the four premium ball and platform sets and real shop', (
    tester,
  ) async {
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
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final balls = BallCosmetic.values.where((b) => b.purchaseOnly).toList();
    final rails = PlatformStyle.values.where((b) => b.purchaseOnly).toList();
    void text(
      Canvas c,
      String value,
      Offset at,
      double size, {
      Color color = const Color(0xFFF5EDE4),
    }) {
      final t = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: size,
            height: 1.5,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 310);
      t.paint(c, at);
      t.dispose();
    }

    final recorder = ui.PictureRecorder();
    // Use the actual play/shop painters, at both gallery and in-game sizes.
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF15222B), BlendMode.src);
    for (var i = 0; i < balls.length; i++) {
      final x = i * 350.0 + 20;
      canvas.save();
      canvas.translate(x, 16);
      text(canvas, balls[i].label.toUpperCase(), const Offset(8, 0), 22);
      text(
        canvas,
        'PREMIUM · COMING SOON',
        const Offset(8, 38),
        12,
        color: const Color(0xFFF4C69C),
      );
      final area = const Rect.fromLTWH(0, 84, 310, 430);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(area, const Radius.circular(22)),
      );
      paintBallWorld(canvas, area, balls[i], reducedMotion: true);
      paintCosmetic(
        canvas,
        area.center - const Offset(0, 10),
        65,
        balls[i],
        time: 2,
      );
      paintPlatformDetail(
        canvas,
        const Offset(18, 452),
        const Offset(292, 452),
        rails[i],
        time: 2,
      );
      paintCosmetic(canvas, const Offset(155, 443), 7, balls[i], time: 2);
      canvas.restore();
      text(canvas, BallWorld.of(balls[i]).name, const Offset(8, 534), 17);
      text(
        canvas,
        '+${formatBoost(balls[i].scoreBonus)}× points · ${balls[i].magnetRadius.toInt()} magnet',
        const Offset(8, 567),
        14,
      );
      text(canvas, rails[i].label, const Offset(8, 618), 19);
      text(
        canvas,
        '+${formatBoost(rails[i].scoreBonus)}× Infinite points',
        const Offset(8, 652),
        14,
        color: const Color(0xFFA5F0DC),
      );
      canvas.save();
      canvas.translate(0, 697);
      canvas.scale(1, 2.5);
      paintPlatformDetail(
        canvas,
        const Offset(18, 0),
        const Offset(292, 0),
        rails[i],
        time: 2,
      );
      canvas.restore();
      canvas.restore();
    }
    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(1400, 730);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts').create(recursive: true);
      await File(
        'artifacts/premium-gear-gallery.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    picture.dispose();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final profile = PlayerProfile()..tutorialSeen = true;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: BallShop(profile: profile)),
        ),
      ),
    );
    await revealShopBall(tester, BallCosmetic.genesis);
    await tester.pump();
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/premium-gear-shop.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await revealShopPlatform(tester, PlatformStyle.genesis);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'artifacts/premium-platform-shop.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
