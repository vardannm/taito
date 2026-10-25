import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ball_world.dart';
import 'game.dart';
import 'infinite_painter.dart';

Object? _cachedSceneKey;
ui.Picture? _cachedScene;

/// Full-width scenery only: interactive objects never enter a blur layer.
void paintWideBoardScenery(
  Canvas canvas,
  Size size,
  BalanceGame game, {
  required Rect sharpArea,
  required Offset worldOffset,
  required double worldScale,
  required bool reducedMotion,
}) {
  final screen = Offset.zero & size;
  final world = Rect.fromLTRB(
    -worldOffset.dx / worldScale,
    -worldOffset.dy / worldScale,
    (size.width - worldOffset.dx) / worldScale,
    (size.height - worldOffset.dy) / worldScale,
  );
  final colors = boardFieldColors(
    game,
  ).map((color) => Color.lerp(color, const Color(0xFF08151E), .46)!).toList();
  final key = (
    size,
    world,
    worldOffset,
    worldScale,
    game.cosmetic,
    colors[0],
    colors[1],
    colors[2],
  );
  if (_cachedSceneKey != key) {
    final recorder = ui.PictureRecorder();
    final scene = Canvas(recorder, screen);
    scene.translate(worldOffset.dx, worldOffset.dy);
    scene.scale(worldScale);
    scene.drawRect(
      world,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(world),
    );
    // Scenery is static; live atmosphere and all actors paint afterward.
    paintBallWorld(
      scene,
      world,
      game.cosmetic,
      background: false,
      reducedMotion: true,
    );
    scene.drawRect(world, Paint()..color = Colors.black.withAlpha(32));
    _cachedScene?.dispose();
    _cachedScene = recorder.endRecording();
    _cachedSceneKey = key;
  }
  final picture = _cachedScene!;
  canvas.drawPicture(picture);

  // Blend two blur strengths continuously across the gutters. One recorded
  // scenery pass is reused; no gameplay, rails, HUD or input is blurred.
  for (final (sigma, power) in [(8.0, 1.0), (28.0, 2.5)]) {
    canvas.saveLayer(
      screen,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawPicture(picture);
    canvas.drawRect(
      screen,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            for (var i = 0; i <= 32; i++)
              Colors.white.withValues(
                alpha: math
                    .pow(
                      wideSceneryBlurAmount(
                        size.width * i / 32,
                        sharpArea,
                        size,
                      ),
                      power,
                    )
                    .toDouble(),
              ),
          ],
          stops: [for (var i = 0; i <= 32; i++) i / 32],
        ).createShader(screen),
    );
    canvas.restore();
  }
  // Ambient ribbons continue beyond both edges; they have no central clip.
  canvas.save();
  canvas.translate(-size.width * .08, worldOffset.dy);
  canvas.scale(worldScale);
  paintInfiniteAtmosphere(
    canvas,
    game,
    reducedMotion,
    subdued: true,
    horizontalSpread: size.width * 1.16 / (360 * worldScale),
  );
  canvas.restore();
}

/// 0 at the playable center, easing to 1 at either physical window edge.
double wideSceneryBlurAmount(double x, Rect sharpArea, Size size) {
  final distance = x < sharpArea.left
      ? (sharpArea.left - x) / math.max(1, sharpArea.left)
      : x > sharpArea.right
      ? (x - sharpArea.right) / math.max(1, size.width - sharpArea.right)
      : 0.0;
  final t = distance.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
