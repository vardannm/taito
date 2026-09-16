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
import 'package:balance_arcade/rewards.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> saveImage(ui.Image image, String path) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

void main() {
  testWidgets('render mastery, daily, cabinet and finale screens', (
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
    for (var level = 1; level <= 45; level++) {
      profile.levelRecords['twoFinger:$level'] = LevelRecord(
        starMask: level % 3 == 0 ? 7 : 3,
        bestScore: 8500 + level * 190,
        bestTime: 105 + level.toDouble(),
        attempts: 4,
      );
    }
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

    await capture('mastery-home');
    await openClassicLevels(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-level-grid');
    await tester.tap(find.text('First steps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-coins');
    final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
    game.won = true;
    game.completed = 10;
    game.target = 11;
    game.phase = GamePhase.over;
    game.elapsed = 82;
    game.score = 18950;
    game.coinsCollected = 2;
    await tester.pump(const Duration(milliseconds: 20));
    await capture('mastery-result');
    await tester.ensureVisible(find.text('BACK TO CLUB'));
    await tester.tap(find.text('BACK TO CLUB'));
    await tester.pump();
    await tester.tap(find.byTooltip('Modes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('DAILY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-daily');
    await tester.ensureVisible(find.text('PLAY DAILY'));
    await tester.tap(find.text('PLAY DAILY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-daily-game');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.text('BACK TO CLUB'));
    await tester.pump();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Cabinet styles'));
    await tester.tap(find.text('Cabinet styles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('cabinet-jade')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-cabinet');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await openClassicLevels(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-50')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('level-50')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('mastery-finale-brief');
    await tester.tap(find.text('START FINALE'));
    await tester.pump();
    game.legTime = 3.1;
    await tester.pump(const Duration(milliseconds: 20));
    await capture('mastery-finale-warning');
    game.specialHazards.first.step(2.5, 0);
    await tester.pump(const Duration(milliseconds: 20));
    await capture('mastery-finale-live');
    game.specialHazards.clear();
    for (final style in CabinetStyle.values) {
      game.cabinet = style;
      await tester.pump(const Duration(milliseconds: 16));
      await capture('mastery-style-${style.name}');
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
