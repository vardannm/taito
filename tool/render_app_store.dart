// Actual Flutter UI captures plus deterministic App Store presentation cards.
// Run: scripts/flutter.ps1 test --no-pub tool/render_app_store.dart
// Optional: --dart-define=STORE_DEVICE=iphone-6-9
// Google Play: --dart-define=STORE_PLATFORM=android (plain Android UI captures).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:balance_arcade/ball_cosmetics.dart';
import 'package:balance_arcade/game.dart';
import 'package:balance_arcade/infinite_boss.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:balance_arcade/main.dart';
import 'package:balance_arcade/merge.dart';
import 'package:balance_arcade/profile.dart';
import 'package:balance_arcade/rewards.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import '../test/support/mode_navigation.dart' show startWorld;
import '../test/support/shop_navigation.dart' show revealShopBall;

const playStore = String.fromEnvironment('STORE_PLATFORM') == 'android';
const outputRoot = String.fromEnvironment(
  'STORE_OUTPUT',
  defaultValue: playStore
      ? 'release/google-play/2026-11-19'
      : 'release/app-store/2026-10-18',
);

class StoreDevice {
  const StoreDevice(
    this.id,
    this.width,
    this.height,
    this.ratio,
    this.top,
    this.bottom,
  );
  final String id;
  final int width, height;
  final double ratio, top, bottom;
  Size get logical => Size(width / ratio, height / ratio);
  bool get tablet => logical.width >= 600;
}

const devices = playStore ? androidDevices : appleDevices;
const androidDevices = [
  StoreDevice('phone', 1080, 1920, 3, 24, 24),
  StoreDevice('tablet-7', 1440, 2560, 2, 24, 24),
  StoreDevice('tablet-10', 1800, 3200, 2, 24, 24),
];
const appleDevices = [
  StoreDevice('iphone-6-3', 1206, 2622, 3, 62, 34),
  StoreDevice('iphone-6-9', 1320, 2868, 3, 62, 34),
  StoreDevice('ipad-13', 2064, 2752, 2, 24, 20),
  StoreDevice('duo-outer', 1398, 2034, 3, 40, 28),
  StoreDevice('duo-inner', 2853, 2007, 3, 28, 24),
];

enum InfiniteScene { early, mid, boss }

class StoreShot {
  const StoreShot(
    this.id,
    this.title,
    this.detail,
    this.tag,
    this.ball,
    this.mode, {
    this.level = 8,
    this.scene = InfiniteScene.early,
    this.bossKind = BossKind.prismReaver,
  });
  final String id, title, detail, tag;
  final BallCosmetic ball;
  final GameMode? mode;

  /// Classic level shown when [mode] is Classic.
  final int level;

  /// Infinite staging when [mode] is Infinite.
  final InfiniteScene scene;
  final BossKind bossKind;
}

const shots = playStore ? playShots : appleShots;

/// Google Play set. Titles only label the manifest; Play images are plain UI.
const playShots = [
  StoreShot(
    '01-boss',
    'Boss encounter',
    'Read the attack. Find your opening.',
    'BOSS',
    BallCosmetic.neon,
    GameMode.infinite,
    scene: InfiniteScene.boss,
    bossKind: BossKind.chronoKeeper,
  ),
  StoreShot(
    '02-infinite-mid',
    'Infinite, deep run',
    'Keep climbing. Build your combo.',
    'INFINITE',
    BallCosmetic.aurora,
    GameMode.infinite,
    scene: InfiniteScene.mid,
  ),
  StoreShot(
    '03-shop',
    'Gear Shop',
    'Discover new ball worlds and gear.',
    'GEAR & WORLDS',
    BallCosmetic.coral,
    null,
  ),
  StoreShot(
    '04-level-23',
    'Classic level 23',
    'Learn the patterns. Master the gaps.',
    'CLASSIC',
    BallCosmetic.pearl,
    GameMode.classic,
    level: 23,
  ),
  StoreShot(
    '05-level-76',
    'Classic level 76',
    'Learn the patterns. Master the gaps.',
    'CLASSIC',
    BallCosmetic.steel,
    GameMode.classic,
    level: 76,
  ),
  StoreShot(
    '06-infinite',
    'Infinite',
    'Find your flow.',
    'INFINITE',
    BallCosmetic.circuit,
    GameMode.infinite,
  ),
];

const appleShots = [
  StoreShot(
    '01-precision',
    'One ball.\nTotal focus.',
    'Lift. Tilt. Chase the glow.',
    'PRECISION ARCADE',
    BallCosmetic.steel,
    GameMode.classic,
  ),
  StoreShot(
    '02-infinite',
    'Find your\nflow.',
    'Keep climbing. Build your combo.',
    'INFINITE',
    BallCosmetic.circuit,
    GameMode.infinite,
  ),
  StoreShot(
    '03-classic',
    '80 levels.\nOne more try.',
    'Learn the patterns. Master the gaps.',
    'CLASSIC',
    BallCosmetic.steel,
    GameMode.classic,
    level: 60,
  ),
  StoreShot(
    '04-boss',
    'Meet your\nnext challenge.',
    'Read the attack. Find your opening.',
    'BOSS ENCOUNTERS',
    BallCosmetic.neon,
    GameMode.infinite,
    scene: InfiniteScene.boss,
  ),
  StoreShot(
    '05-merge',
    'Match. Merge.\nKeep rolling.',
    'Match numbers. Build your chain.',
    'NUMBER MERGE',
    BallCosmetic.steel,
    GameMode.merge2048,
  ),
  StoreShot(
    '06-gear',
    'Play it\nyour way.',
    'Discover new ball worlds and gear.',
    'GEAR & WORLDS',
    BallCosmetic.coral,
    null,
  ),
];

void main() {
  testWidgets('capture store sets from the current app UI', (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = playStore
        ? TargetPlatform.android
        : TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
    for (final family in [
      'sans-serif',
      'monospace',
      'Roboto',
      'MaterialIcons',
    ]) {
      final file = family == 'MaterialIcons'
          ? 'materialicons-regular.otf'
          : 'roboto-regular.ttf';
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/$file',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    final manifest = <Map<String, Object>>[];
    for (final device in devices) {
      const onlyDevice = String.fromEnvironment('STORE_DEVICE');
      if (onlyDevice.isNotEmpty && device.id != onlyDevice) continue;
      tester.view.devicePixelRatio = device.ratio;
      tester.view.physicalSize = Size(
        device.width.toDouble(),
        device.height.toDouble(),
      );
      tester.view.padding = FakeViewPadding(
        top: device.top * device.ratio,
        bottom: device.bottom * device.ratio,
      );
      for (final shot in shots) {
        const onlyShots = String.fromEnvironment('STORE_SHOTS');
        if (onlyShots.isNotEmpty && !onlyShots.split(',').contains(shot.id)) {
          continue;
        }
        await tester.pumpWidget(const SizedBox());
        final profile = PlayerProfile()
          ..tutorialSeen = true
          ..sound = false
          ..music = false
          ..haptics = false
          // Play shows an affordable featured ball rather than a coin shortfall.
          ..wallet = playStore ? 4820 : 420
          ..controlMode = device.tablet
              ? ControlMode.twoFinger
              : ControlMode.oneFinger
          ..classicLevel = shot.level
          ..selectedBall = shot.ball;
        profile.ownedBalls.addAll([
          BallCosmetic.coral,
          BallCosmetic.circuit,
          BallCosmetic.neon,
          shot.ball,
        ]);
        for (var level = 1; level < profile.classicLevel; level++) {
          profile.levelRecords[profile.recordKey(
            level,
            profile.controlMode,
          )] = const LevelRecord(
            starMask: 7,
            bestScore: 14280,
            bestTime: 218,
            attempts: 4,
          );
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ArcadeApp(profile: profile),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        final dynamic state = tester.state(find.byType(GameScreen));
        if (shot.mode == null) {
          await tester.tap(find.byKey(const ValueKey('board-shop')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await revealShopBall(tester, BallCosmetic.nebula);
          final featuredBall = find.byKey(
            const ValueKey('world-preview-nebula'),
          );
          await Scrollable.ensureVisible(
            tester.element(featuredBall),
            alignment: 0,
          );
          await tester.pump(const Duration(milliseconds: 400));
        } else {
          state.start(shot.mode!);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          if (shot.mode == GameMode.infinite) {
            await startWorld(tester);
            await tester.pump(const Duration(milliseconds: 650));
          }
          // Finale levels open on a briefing card; start them like a player.
          if (find.text('START LEVEL').evaluate().isNotEmpty) {
            await tester.tap(find.text('START LEVEL'));
            await tester.pump();
          }
          state.ticker.stop();
          final game = tester.widget<PivotBoard>(find.byType(PivotBoard)).game;
          if (game.infinite) {
            stageInfinite(game, shot);
          } else if (game.merging) {
            stageMerge(game);
          } else {
            stageClassic(game, shot.level);
          }
          // This updates the same HUD, backdrop and board notifiers as gameplay.
          state.previous = const Duration(milliseconds: 1000);
          state.accumulator = 0.0;
          state.tick(const Duration(milliseconds: 1000));
          state.ticker.stop();
          await tester.pump();
          expect(game.finished, isFalse, reason: '${device.id}/${shot.id}');
          expect(game.paused, isFalse);
          expect(game.waitingForInput, isFalse);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${device.id}/${shot.id}',
        );
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final raw = await render.toImage(pixelRatio: device.ratio);
        expect((raw.width, raw.height), (device.width, device.height));
        final rawPath = '$outputRoot/source-ui/${device.id}/${shot.id}.png';
        await tester.runAsync(() => saveRgb(raw, rawPath));
        final composed = playStore
            ? raw
            : await presentation(raw, device, shot);
        final finalPath = '$outputRoot/screenshots/${device.id}/${shot.id}.png';
        await tester.runAsync(() => saveRgb(composed, finalPath));
        manifest.add({
          'device': device.id,
          'width': device.width,
          'height': device.height,
          'shot': shot.id,
          'title': shot.title.replaceAll('\n', ' '),
          'file': 'screenshots/${device.id}/${shot.id}.png',
          'source': 'source-ui/${device.id}/${shot.id}.png',
          'capture': playStore
              ? 'Current Flutter app UI rendered with Android target platform; staged gameplay, not a physical-device capture'
              : 'Flutter app UI rendered with iOS target platform; not a native iOS device capture',
          'pngColorType': 2,
        });
        if (!identical(composed, raw)) composed.dispose();
        raw.dispose();
        print(
          'Captured ${device.id}/${shot.id} (${device.width}x${device.height}, RGB)',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(
      manifest,
      isNotEmpty,
      reason: 'The device/shot filters matched no captures.',
    );
    final suffix = const String.fromEnvironment('STORE_DEVICE');
    final selection = const String.fromEnvironment('STORE_SHOTS');
    await tester.runAsync(() async {
      final file = File(
        '$outputRoot/manifest${suffix.isEmpty ? '' : '-$suffix'}${selection.isEmpty ? '' : '-selected'}.json',
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
      );
    });
    debugDefaultTargetPlatformOverride = previousPlatform;
  }, timeout: const Timeout(Duration(minutes: 8)));
}

void stageClassic(BalanceGame game, int level) {
  // Mid-level progress: target, score and time grow with the level.
  final (target, score, elapsed) = switch (level) {
    <= 8 => (3, 1760, 38.2),
    <= 30 => (5, 3120, 51.6),
    <= 60 => (4, 3810, 73.4),
    _ => (5, 4970, 84.9),
  };
  game.target = target;
  game.completed = game.target - 1;
  game.score = score;
  game.streak = game.completed;
  game.elapsed = elapsed;
  game.message = '';
  game.clock = 12.2;
  game.velocity = 0;
  // Find an authentic stationary pose away from holes and undisturbed keepers.
  var best = double.infinity;
  for (var y = 350.0; y <= 440; y += 10) {
    for (var x = 100.0; x <= 260; x += 10) {
      if (game.board.any(
        (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) < 25 * 25,
      ))
        continue;
      if (game.spiders.any(
        (s) =>
            math.pow(s.homeX - x, 2) + math.pow(s.homeY - y, 2) <
            math.pow(s.zoneRadius + 20, 2),
      ))
        continue;
      final rank = (x - 180).abs() + (y - 410).abs();
      if (rank < best) {
        best = rank;
        game.ballX = x;
        game.left = game.right = y + 7;
      }
    }
  }
  // Moving holes persist from level start, rather than appearing as
  // target-specific timed waves. Capture those real instances in motion.
  for (final hazard in game.specialHazards) {
    hazard.step(1.1, 0);
  }
}

void stageInfinite(BalanceGame game, StoreShot shot) {
  final boss = shot.scene == InfiniteScene.boss;
  final mid = shot.scene == InfiniteScene.mid;
  final camera = boss
      ? 82000.0
      : mid
      ? 31200.0
      : 7600.0;
  game.cameraOffset = camera;
  game.maxHeight = camera + 400;
  game.dangerY = 620 - camera;
  game.ballX = boss
      ? 240
      : mid
      ? 196
      : 178;
  // A valid raised-platform pose keeps the boss in view on shorter displays.
  game.left = (boss ? 338 : mid ? 414 : 438) - camera;
  game.right = (boss ? 324 : mid ? 432 : 414) - camera;
  game.velocity = 0;
  game.controlPosition = (game.right - game.left) / 140;
  game.score = boss
      ? 912840
      : mid
      ? 186320
      : 18460;
  game.survival.points = game.score.toDouble();
  game.elapsed = boss
      ? 642
      : mid
      ? 318
      : 146;
  game.clock = 13.2;
  game.survival.scoredMetres = game.metres.toDouble();
  game.survival.combo = boss
      ? 4
      : mid
      ? 9
      : 7;
  game.survival.bestCombo = game.survival.combo;
  game.survival.visualCombo = (game.survival.combo - 1) / 9;
  game.survival.shield = boss || mid ? 0 : 6.4;
  game.coinsCollected = boss
      ? 86
      : mid
      ? 58
      : 24;
  // The deep run uses a denser, mirrored course so it reads differently.
  final holes = mid
      ? [
          (284.0, 130.0),
          (92.0, 172.0),
          (210.0, 232.0),
          (62.0, 300.0),
          (250.0, 318.0),
          (140.0, 372.0),
        ]
      : [(78.0, 155.0), (266.0, 190.0), (116.0, 284.0), (296.0, 340.0)];
  final coins = mid
      ? [(150.0, 118.0), (180.0, 150.0), (210.0, 182.0), (300.0, 262.0)]
      : [(216.0, 140.0), (154.0, 237.0), (218.0, 315.0), (126.0, 370.0)];
  game.board
    ..clear()
    ..addAll([for (final p in holes) Hole(p.$1, p.$2 - camera)]);
  game.coins
    ..clear()
    ..addAll([for (final p in coins) BrassCoin(p.$1, p.$2 - camera)]);
  game.survival.items
    ..clear()
    ..addAll(
      mid
          ? [
              InfiniteItem(InfiniteItemKind.combo, 120, 250 - camera),
              InfiniteItem(InfiniteItemKind.magnet, 300, 200 - camera),
            ]
          : [
              InfiniteItem(InfiniteItemKind.combo, 178, 190 - camera),
              InfiniteItem(InfiniteItemKind.combo, 210, 360 - camera),
              InfiniteItem(InfiniteItemKind.magnet, 68, 314 - camera),
            ],
    );
  game.specialHazards.clear();
  if (boss) {
    game.board.clear();
    game.survival.items.clear();
    game.coins.clear();
    final encounter = InfiniteBoss(
      kind: shot.bossKind,
      top: game.visibleTop,
      seed: 14,
    );
    for (var age = 0.0; age < 20.4; age += 1 / 120) {
      encounter.step(
        1 / 120,
        target: (x: game.ballX, y: game.screenY(game.ballY)),
        scrollDistance: 100 / 120,
        visibleTop: game.visibleTop,
      );
    }
    game.boss = encounter;
  }
}

void stageMerge(BalanceGame game) {
  final run = game.mergeRun;
  run.segments
    ..clear()
    ..addAll([128, 64, 32, 16, 8]);
  run.highest = 128;
  run.score = 3820;
  game.score = 3820;
  game.ballX = 180;
  game.left = game.right = 398;
  game.velocity = 0;
  run.orbs
    ..clear()
    ..addAll([
      NumberOrb(80, 110, 32),
      NumberOrb(245, 150, 256),
      NumberOrb(175, 220, 128),
      NumberOrb(72, 287, 64),
      NumberOrb(278, 330, 32),
    ]);
  run.gates
    ..clear()
    ..add(MergeGate(64, y: 180));
  run.notice = '';
  game.clock = 10.8;
}

Future<ui.Image> presentation(
  ui.Image raw,
  StoreDevice device,
  StoreShot shot,
) async {
  final w = device.width.toDouble(), h = device.height.toDouble();
  final recorder = ui.PictureRecorder();
  // The finished image has an opaque background and a single, unaltered UI capture.
  final c = Canvas(recorder), bounds = Rect.fromLTWH(0, 0, w, h);
  c.drawRect(
    bounds,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), [
        const Color(0xff102a30),
        const Color(0xff081519),
      ]),
  );
  c.drawCircle(
    Offset(w * .9, h * .5),
    w * .85,
    Paint()
      ..shader = ui.Gradient.radial(Offset(w * .9, h * .5), w * .85, [
        const Color(0x1938bba1),
        const Color(0x0038bba1),
      ]),
  );
  final wide = w / h > .6;
  final landscape = w > h;
  final margin = w * .075;
  final logo = _text(
    'ROLLRISE',
    w * .033,
    const Color(0xffe9c47c),
    weight: FontWeight.w800,
    spacing: w * .008,
  );
  logo.paint(c, Offset(margin, h * .035));
  final tag = _text(
    shot.tag,
    w * .019,
    const Color(0xffa9c1c2),
    spacing: w * .0025,
  );
  tag.paint(c, Offset(w - margin - tag.width, h * .039));
  final title = _text(
    landscape ? shot.title.replaceAll('\n', ' ') : shot.title,
    w * (landscape ? .047 : (wide ? .059 : .081)),
    const Color(0xfff5f0e4),
    weight: FontWeight.w900,
    height: 1.04,
    spacing: -w * .002,
  );
  title.paint(c, Offset(margin, h * (wide ? .078 : .087)));
  final body = _text(
    shot.detail,
    w * (landscape ? .018 : (wide ? .020 : .027)),
    const Color(0xffb7cbca),
  );
  final bodyY = h * (wide ? .078 : .087) + title.height + h * .014;
  body.paint(c, Offset(margin, bodyY));
  final availableTop = bodyY + body.height + h * .032;
  final availableBottom = h * .955;
  final scale = math.min(
    (w - margin * 2) / raw.width,
    (availableBottom - availableTop) / raw.height,
  );
  final rect = Rect.fromLTWH(
    (w - raw.width * scale) / 2,
    availableTop,
    raw.width * scale,
    raw.height * scale,
  );
  final frame = RRect.fromRectAndRadius(rect, Radius.circular(w * .022));
  c.drawShadow(
    Path()..addRRect(frame),
    Colors.black.withAlpha(180),
    w * .024,
    true,
  );
  c.save();
  c.clipRRect(frame);
  c.drawImageRect(
    raw,
    Rect.fromLTWH(0, 0, raw.width.toDouble(), raw.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
  c.drawRRect(
    frame,
    Paint()
      ..color = const Color(0xff426568)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .0013,
  );
  final footer = _text(
    'PRECISION IS EVERYTHING',
    w * .015,
    const Color(0xff7f9c9e),
    spacing: w * .0028,
  );
  footer.paint(c, Offset((w - footer.width) / 2, h * .976 - footer.height / 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(device.width, device.height);
  picture.dispose();
  return image;
}

TextPainter _text(
  String value,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double spacing = 0,
  double height = 1.15,
}) => TextPainter(
  text: TextSpan(
    text: value,
    style: TextStyle(
      fontFamily: 'sans-serif',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// Write true RGB PNGs (color type 2), not opaque-looking RGBA PNGs.
/// Apple rejects an alpha channel even when every alpha byte is 255.
Future<void> saveRgb(ui.Image image, String path) async {
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgba = raw!.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
  final rows = Uint8List((image.width * 3 + 1) * image.height);
  var out = 0, at = 0;
  for (var y = 0; y < image.height; y++) {
    rows[out++] = 0;
    for (var x = 0; x < image.width; x++) {
      final alpha = rgba[at + 3];
      for (var channel = 0; channel < 3; channel++) {
        // Flatten the occasional transparent edge against the app's dark surface.
        rows[out++] = alpha == 255
            ? rgba[at + channel]
            : ((rgba[at + channel] * alpha + 13 * (255 - alpha)) / 255).round();
      }
      at += 4;
    }
  }
  final header = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final png = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final bytes = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    png
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(bytes)
      ..add(
        (ByteData(
          4,
        )..setUint32(0, (crc ^ 0xffffffff) & 0xffffffff)).buffer.asUint8List(),
      );
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder(level: 6).convert(rows));
  chunk('IEND', []);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png.takeBytes());
}
