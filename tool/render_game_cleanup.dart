import 'dart:io';
import 'dart:ui' as ui;
import 'package:balance_arcade/main.dart';
import '../test/support/mode_navigation.dart' show armWorld, startWorld;
import 'package:balance_arcade/onboarding.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'render starter world, shop hint, collection and current tutorial',
    (tester) async {
      for (final family in ['sans-serif', 'monospace', 'MaterialIcons']) {
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
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final boundary = GlobalKey();
      PlayerProfile profile({TutorialStep? lesson}) => PlayerProfile()
        ..tutorialSeen = lesson == null
        ..tutorial = TutorialProgress(step: lesson ?? TutorialStep.completed)
        ..wallet = 150
        ..sound = false
        ..music = false
        ..haptics = false;
      Future<void> show(PlayerProfile p) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ArcadeApp(profile: p),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
      }

      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        final output =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        await tester.runAsync(() async {
          final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
          await Directory('artifacts/game-cleanup').create(recursive: true);
          await File(
            'artifacts/game-cleanup/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        output.dispose();
      }

      for (final size in [const Size(320, 568), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        final width = size.width.toInt();
        await show(profile());
        await capture('starter-$width');
        await armWorld(tester);
        await capture('infinite-waiting-$width');
        await startWorld(tester);
        await tester.pump(const Duration(milliseconds: 16));
        await capture('infinite-playing-$width');
        await tester.pumpWidget(const SizedBox());
        await show(profile());
        await tester.tap(find.byKey(const ValueKey('board-shop')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await capture('shop-$width');
        await tester.tap(find.text('Upgrades'));
        await tester.pump();
        await capture('upgrades-$width');
        await tester.tap(find.byTooltip('Done shopping'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byTooltip('Modes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.text('HOW TO PLAY'));
        await tester.tap(find.text('HOW TO PLAY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await capture('guide-$width');
        await tester.pumpWidget(const SizedBox());
        await show(profile(lesson: TutorialStep.controls));
        await capture('tutorial-controls-$width');
        await tester.pumpWidget(const SizedBox());
        await show(profile(lesson: TutorialStep.magnetFeedback));
        await capture('tutorial-magnet-$width');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
