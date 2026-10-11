import 'dart:io';
import 'dart:ui' as ui;
import '../test/support/mode_navigation.dart' show startWorld, armWorld;

import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'premium menu fits notches, short phones, tablets and alternate controls',
    (tester) async {
      for (final family in ['sans-serif', 'MaterialIcons']) {
        final loader = FontLoader(family)
          ..addFont(
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
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      for (final sample in [
        (
          'short',
          const Size(320, 480),
          BallCosmetic.steel,
          ControlMode.oneFinger,
          1.0,
        ),
        (
          'short-large',
          const Size(320, 480),
          BallCosmetic.prism,
          ControlMode.oneFinger,
          1.8,
        ),
        (
          'notched',
          const Size(430, 932),
          BallCosmetic.aurora,
          ControlMode.oneFinger,
          1.0,
        ),
        (
          'analog',
          const Size(390, 844),
          BallCosmetic.obsidian,
          ControlMode.analog,
          1.0,
        ),
        (
          'tablet',
          const Size(800, 1200),
          BallCosmetic.singularity,
          ControlMode.twoFinger,
          1.0,
        ),
      ]) {
        tester.view.physicalSize = sample.$2;
        tester.view.padding = FakeViewPadding(
          top: sample.$1 == 'notched' ? 59 : 44,
          bottom: 34,
          left: sample.$1 == 'tablet' ? 12 : 0,
          right: sample.$1 == 'tablet' ? 12 : 0,
        );
        tester.platformDispatcher.textScaleFactorTestValue = sample.$5;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        final profile = PlayerProfile()
          ..tutorialSeen = true
          ..sound = false
          ..music = false
          ..haptics = false
          ..selectedBall = sample.$3
          ..controlMode = sample.$4
          ..infiniteBestScore = 148620;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ArcadeApp(profile: profile),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: sample.$1);
        final play = tester.getRect(find.byKey(const ValueKey('menu-play')));
        expect(play.height, greaterThanOrEqualTo(48));
        expect(play.top, greaterThan(44));
        expect(play.bottom, lessThanOrEqualTo(sample.$2.height - 34));
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('menu-best-score')))
              .data,
          '148,620',
        );
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: sample.$1 == 'tablet' ? 1 : 2);
        await tester.runAsync(() async {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'artifacts/premium-menu-${sample.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
        Future<void> captureState(String state) async {
          expect(tester.takeException(), isNull, reason: '$state ${sample.$1}');
          final rendered =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          await tester.runAsync(() async {
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/$state-${sample.$1}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
          rendered.dispose();
        }

        await armWorld(tester);
        expect(
          find.byKey(const ValueKey('start-control-prompt')),
          findsOneWidget,
        );
        await captureState('control-prompt');
        await startWorld(tester);
        await tester.pump();
        final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
        expect(game.waitingForInput, isFalse);
        expect(game.cosmetic, sample.$3);
        expect(tester.takeException(), isNull, reason: '${sample.$1} play');
        await tester.tap(find.byTooltip('Pause'));
        await tester.pump();
        await captureState('pause-menu');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
