import 'ball_painter.dart';
import 'ball_world.dart';
import 'platform_painter.dart';
import 'infinite_painter.dart';
import 'merge_widgets.dart';
import 'merge.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game.dart';
import 'hazards.dart';
import 'hazard_painter.dart';
import 'spider_painter.dart';
import 'porcupine_painter.dart';
import 'snake_painter.dart';
import 'late_enemy_painter.dart';
import 'infinite_boss.dart';
import 'infinite_boss_painter.dart';
import 'cabinet.dart';
import 'heart_loss_effect.dart';
import 'pickup_painter.dart';

const cream = Color(0xFFF2ECDD);
const ink = Color(0xFF163D3B);
const orange = Color(0xFFCD542F);
const brass = Color(0xFFD9AE65);

/// Height kept below the board for the controls: the one-finger thumb pad,
/// or the strip where two-finger handles sit under the platform. Both modes
/// share it, so the board and ball sit at the same place on screen.
const controlStripHeight = 96.0;
const haloControlStripHeight = 140.0;

/// The strip a full-size board widget lays its board out above. One-finger
/// places its pad outside the board widget instead, so it needs none here.
double handleStrip(BalanceGame game) =>
    game.controlMode == ControlMode.twoFinger ? controlStripHeight : 0;

/// The strip below the board across the whole play area, pad or handles.
double controlStrip(BalanceGame game) => game.oneFinger && game.haloJoystick
    ? haloControlStripHeight
    : game.oneFinger || game.controlMode == ControlMode.twoFinger
    ? controlStripHeight
    : 0;

/// One transform shared by rendering and pointer hit testing.
class BoardViewport {
  /// [bottomInset] keeps a strip below the board for the controls: the board
  /// is laid out above it, and two-finger handles may sit inside it.
  BoardViewport(
    Size full, {
    double fillWidth = 0,
    double focusY = 440,
    double bottomInset = 0,
  }) {
    final size = Size(full.width, math.max(1, full.height - bottomInset));
    bounds = Offset.zero & size;
    // Without a strip, handles stay on the visible board as before.
    controlBottom = bottomInset > 0 ? full.height : 0;
    final fit = math.min(
      size.width / BalanceGame.width,
      size.height / BalanceGame.height,
    );
    scale =
        fit +
        (size.width / BalanceGame.width - fit) * fillWidth.clamp(0.0, 1.0);
    final height = BalanceGame.height * scale;
    topExtension =
        math.max(0, size.height - height) / scale * fillWidth.clamp(0.0, 1.0);
    offset = Offset(
      (size.width - BalanceGame.width * scale) / 2,
      // Slack sits above the board during a run so it rests near the control
      // area instead of leaving a gap between the two.
      height <= size.height
          ? (size.height - height) * (.5 + .5 * fillWidth.clamp(0.0, 1.0))
          : (size.height * .72 - focusY * scale).clamp(
              size.height - height,
              0.0,
            ),
    );
  }

  /// For a board widget of [size]. Two-finger keeps its handle strip inside
  /// that size unless [bottomInset] says otherwise.
  factory BoardViewport.forGame(
    Size size,
    BalanceGame game, {
    double fillWidth = 0,
    double? bottomInset,
  }) => BoardViewport(
    size,
    fillWidth: fillWidth,
    bottomInset: bottomInset ?? handleStrip(game),
    focusY: game.screenY((game.left + game.right) / 2),
  );
  late final double scale;
  late final double topExtension;
  late Offset offset;
  late final Rect bounds;

  /// Bottom of the control strip below the board, or 0 when there is none.
  late final double controlBottom;
  Offset project(Offset point) => offset + point * scale;

  /// Screen-space spacing keeps a thumb clear of the ball at every board scale.
  Offset gripCenter(BalanceGame game, int side, {double? heldOffset}) {
    final pivot = project(
      Offset(
        side == 0 ? 20 : 340,
        game.screenY(side == 0 ? game.left : game.right),
      ),
    );
    // At the very bottom, use the space above instead of covering the ball or
    // drawing an unreachable handle outside the screen.
    final dy =
        heldOffset ?? (pivot.dy + 64 + 24 <= gripArea.bottom ? 64.0 : -64.0);
    return pivot + Offset(0, dy);
  }

  /// The visible board plus the control strip below it.
  Rect get gripArea {
    final visible = rect.intersect(bounds);
    return Rect.fromLTRB(
      visible.left,
      visible.top,
      visible.right,
      math.max(visible.bottom, controlBottom),
    );
  }

  bool hitsGrip(Offset point, BalanceGame game, int side) {
    final grip = gripCenter(game, side);
    return gripArea.contains(point) &&
        (point.dx - grip.dx).abs() <= 44 &&
        (point.dy - grip.dy).abs() <= 24;
  }

  Rect get rect =>
      (offset - Offset(0, topExtension * scale)) &
      Size(
        BalanceGame.width * scale,
        (BalanceGame.height + topExtension) * scale,
      );
}

class BoardPainter extends CustomPainter {
  // Shared across painter rebuilds, but bounded so a long Infinite run cannot
  // retain every distance/score label. Evicted native paragraphs are disposed.
  static final _labels =
      <(String, double, Color, FontWeight, double), TextPainter>{};
  BoardPainter(
    this.game, {
    this.reducedMotion = false,
    this.fillWidth = 0,
    this.showHud = true,
    this.gripOffsets = const {},
    Listenable? repaint,
  }) : world = BallWorld.of(game.cosmetic),
       super(repaint: repaint);
  final BalanceGame game;
  final BallWorld world;
  final bool reducedMotion;
  final double fillWidth;
  final bool showHud;
  final Map<int, double> gripOffsets;

  void text(
    Canvas c,
    String value,
    Offset point,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
    double spacing = 0,
    bool centered = true,
  }) {
    final key = (value, size, color, weight, spacing);
    final p =
        _labels.remove(key) ??
        (TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: size,
              color: color,
              fontWeight: weight,
              letterSpacing: spacing,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout());
    _labels[key] = p;
    if (_labels.length > 128) {
      _labels.remove(_labels.keys.first)!.dispose();
    }
    p.paint(c, point - Offset(centered ? p.width / 2 : 0, p.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final palette = CabinetPalette.of(game.cabinet);
    final ink = infiniteBoardInk(game, const Offset(180, 270)),
        brass = palette.trim;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final viewport = BoardViewport.forGame(size, game, fillWidth: fillWidth);
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.scale);
    final top = -viewport.topExtension;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, top, 360, 560),
      const Radius.circular(22),
    );
    canvas.drawRRect(outer, Paint()..color = palette.frame);
    canvas.drawRRect(
      outer.deflate(2),
      Paint()
        ..color = brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final field = RRect.fromRectAndRadius(
      Rect.fromLTRB(10, top + 10, 350, 550),
      const Radius.circular(15),
    );
    canvas.drawRRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: boardFieldColors(game),
        ).createShader(field.outerRect),
    );
    canvas.save();
    canvas.clipRRect(field);
    paintInfiniteAtmosphere(canvas, game, reducedMotion);
    paintBallWorld(
      canvas,
      field.outerRect,
      game.cosmetic,
      background: false,
      time: game.clock,
      reducedMotion: reducedMotion,
      energy: game.infinite ? game.survival.visualCombo : 0,
    );
    final grain = Paint()
      ..color = ink.withAlpha(50)
      ..strokeWidth = .6;
    final railTop = game.infinite ? game.screenY(game.minPivot) : top + 26;
    for (final x in [20.0, 340.0]) {
      canvas.drawLine(
        Offset(x, railTop),
        Offset(x, 534),
        Paint()
          ..color = const Color(0xFF574A31)
          ..strokeWidth = 5,
      );
      canvas.drawLine(
        Offset(x - 1, railTop),
        Offset(x - 1, 534),
        Paint()
          ..color = const Color(0xFFEEE7CC)
          ..strokeWidth = 1,
      );
      for (double y = railTop + 6; y < 530; y += 10) {
        canvas.drawLine(
          Offset(x == 20 ? 26 : 329, y),
          Offset(x == 20 ? 30 : 333, y),
          grain..color = ink.withAlpha(75),
        );
      }
      if (game.infinite) {
        final stop = RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 9, railTop - 8, x + 9, railTop),
          const Radius.circular(2),
        );
        canvas.drawRRect(stop.shift(const Offset(0, 2)), Paint()..color = ink);
        canvas.drawRRect(stop, Paint()..color = brass);
        canvas.drawLine(
          Offset(x - 6, railTop - 6),
          Offset(x + 6, railTop - 6),
          Paint()
            ..color = const Color(0xFFFFF2CE)
            ..strokeWidth = 1,
        );
        for (final dx in [-5.0, 5.0]) {
          canvas.drawCircle(
            Offset(x + dx, railTop - 3),
            1,
            Paint()..color = ink,
          );
        }
      }
    }
    if (game.merging) {
      for (final orb in game.mergeRun.orbs) {
        paintNumberOrb(
          canvas,
          Offset(orb.x, orb.y),
          orb.value,
          MergeRun.fallingRadius,
          match: game.mergeRun.canMerge(orb.value),
          danger: orb.value > game.mergeRun.head,
        );
      }
      for (final gate in game.mergeRun.gates) {
        final color = game.mergeRun.head > gate.requiredValue ? ink : orange;
        canvas.drawLine(
          Offset(20, gate.y),
          Offset(340, gate.y),
          Paint()
            ..color = color.withAlpha(50)
            ..strokeWidth = 14,
        );
        canvas.drawLine(
          Offset(20, gate.y),
          Offset(340, gate.y),
          Paint()
            ..color = color
            ..strokeWidth = 3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(180, gate.y),
              width: 150,
              height: 30,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = color,
        );
        text(
          canvas,
          '> ${gate.requiredValue}',
          Offset(180, gate.y),
          15,
          contrastInk(color),
        );
      }
      if (game.mergeRun.flash > 0) {
        text(canvas, game.mergeRun.notice, const Offset(180, 28), 10, ink);
      }
    }
    paintSpiderBackdrop(canvas, game);
    final visibleHoles = game.board;
    for (final hole in visibleHoles) {
      final p = Offset(hole.x, game.screenY(hole.y));
      if (p.dy < top - 32 || p.dy > 592) continue;
      final active = !game.infinite && hole.target == game.target.clamp(1, 10);
      final done = hole.target > 0 && hole.target < game.target;
      if (active) {
        final pulse = reducedMotion ? .5 : (math.sin(game.clock * 3.5) + 1) / 2;
        canvas.drawCircle(
          p,
          23 + pulse * 3,
          Paint()
            ..color = const Color(0xFFEAFFF3).withAlpha(90)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawCircle(
          p,
          18 + pulse * 2,
          Paint()
            ..color = ink.withAlpha(120)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8,
        );
        for (int i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          canvas.drawLine(
            p + Offset(math.cos(angle) * 22, math.sin(angle) * 22),
            p + Offset(math.cos(angle) * 25, math.sin(angle) * 25),
            Paint()
              ..color = ink
              ..strokeWidth = 1.5,
          );
        }
      }
      canvas.drawCircle(
        p + const Offset(0, 1.5),
        13.5,
        Paint()..color = const Color(0xFFFFE9B7),
      );
      canvas.drawCircle(
        p,
        12.8,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF77542F), Color(0xFFC29251)],
          ).createShader(Rect.fromCircle(center: p, radius: 13)),
      );
      canvas.drawCircle(p, 10.4, Paint()..color = const Color(0xFF192F2D));
      canvas.drawCircle(
        p - const Offset(0, 2),
        8,
        Paint()..color = const Color(0xFF102422),
      );
      if (active || done)
        canvas.drawCircle(
          p,
          12.3,
          Paint()
            ..color = active ? const Color(0xFFDCFAD9) : ink.withAlpha(150)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2.5 : 1.5,
        );
      if (hole.target > 0)
        text(
          canvas,
          done ? '·' : '${hole.target}'.padLeft(2, '0'),
          p,
          9,
          active ? const Color(0xFFE7FFD7) : brass,
          weight: FontWeight.w700,
        );
    }
    // Keep the maker's mark on previews only.
    if (showHud)
      text(
        canvas,
        'PRECISION IS EVERYTHING',
        const Offset(180, 545),
        6.5,
        game.infinite
            ? infiniteBoardInk(game, const Offset(180, 545))
            : ink.withAlpha(180),
        spacing: 2,
      );
    if (game.infinite) {
      for (
        int mark = (game.maxHeight / 100).floor() - 4;
        mark < (game.maxHeight / 100).floor() + 7;
        mark++
      ) {
        final y = game.screenY(
          BalanceGame.infiniteStart - BalanceGame.ballRadius - mark * 100.0,
        );
        if (mark >= 0 && y > 28 && y < 530) {
          text(
            canvas,
            '${mark * 10}m',
            Offset(315, y),
            7,
            infiniteBoardInk(game, Offset(315, y)),
          );
          canvas.drawLine(
            Offset(30, y),
            Offset(42, y),
            Paint()
              ..color = infiniteBoardInk(game, Offset(36, y)).withAlpha(180)
              ..strokeWidth = 1,
          );
        }
      }
      final top = game.screenY(game.dangerY).clamp(10.0, 550.0);
      if (top < 550) {
        final danger = Rect.fromLTRB(10, top, 350, 550);
        canvas.drawRect(
          danger,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x88F24B38), Color(0xE0AC231C)],
            ).createShader(danger),
        );
        canvas.drawLine(
          Offset(10, top),
          Offset(350, top),
          Paint()
            ..color = const Color(0xFFFF6852)
            ..strokeWidth = 3,
        );
        text(
          canvas,
          'KEEP STEERING',
          Offset(180, math.min(top + 18, 530)),
          9,
          cream,
          spacing: 2,
        );
      }
    }
    for (final coin in game.coins.where((c) => !c.collected)) {
      final p = Offset(coin.x, game.screenY(coin.y));
      if (p.dy < top - 12 || p.dy > 572) continue;
      // Each coin turns from its own angle, so a row never flips in unison.
      paintBrassCoin(
        canvas,
        p,
        6.6,
        reducedMotion ? 1 : math.cos(game.clock * 1.9 + coin.x * .12),
      );
    }
    if (game.lastCoinAge < .7) {
      text(
        canvas,
        game.scrolling ? '+1 COIN' : '+250',
        Offset(
          game.lastCoinX,
          game.screenY(game.lastCoinY) -
              12 -
              (reducedMotion ? 0 : game.lastCoinAge * 20),
        ),
        11,
        game.infinite
            ? infiniteBoardInk(
                game,
                Offset(game.lastCoinX, game.screenY(game.lastCoinY) - 20),
              )
            : ink,
      );
    }
    paintInfiniteItems(canvas, game, reducedMotion);
    paintMazeGates(canvas, game, reducedMotion);
    paintSpecialHazards(canvas, game, reducedMotion);
    paintSpiders(canvas, game, reducedMotion);
    paintSpiderWebShots(canvas, game, reducedMotion);
    paintPorcupines(canvas, game, reducedMotion);
    paintSnakes(canvas, game, reducedMotion);
    paintLateEnemy(canvas, game, reducedMotion);
    paintInfiniteBoss(canvas, game, reducedMotion);
    final boss = game.boss;
    if (boss != null && boss.phase != BossPhase.leaving) {
      final labelY =
          boss.top + (boss.kind == BossKind.eclipseSeraph ? 205 : 165);
      final bossInk = infiniteBoardInk(game, Offset(180, labelY));
      text(
        canvas,
        boss.displayName,
        Offset(180, labelY),
        11,
        bossInk,
        weight: FontWeight.w800,
        spacing: 2,
      );
      text(
        canvas,
        '${switch (boss.phase) {
          BossPhase.sweepingLaser => 'LASER SWEEP',
          BossPhase.twinLasers => 'TWIN LASERS',
          BossPhase.rotors => 'SPINNING ROTORS',
          BossPhase.toxicSlalom => 'TOXIC SLALOM',
          BossPhase.toxicPulse => 'POISON PULSE',
          BossPhase.toxicGauntlet => 'TOXIC GAUNTLET',
          _ => boss.phase.name.toUpperCase(),
        }} · ${(InfiniteBoss.duration - boss.age).ceil()}s',
        Offset(180, labelY + 16),
        9,
        bossInk,
      );
    }
    if (game.infinite && showHud) {
      // Lives ride in the board's own top-left corner, just clear of the rail.
      canvas.save();
      canvas.translate(38, 31);
      for (var i = 0; i < 3; i++) {
        final held = i < game.lives;
        canvas.save();
        canvas.scale(.74);
        canvas.drawPath(
          HeartLossPainter.heart,
          Paint()
            ..color = orange.withValues(alpha: held ? .9 : .3)
            ..style = held ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        canvas.restore();
        canvas.translate(22, 0);
      }
      canvas.restore();
    }
    if (game.infinite && showHud) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(258, 20, 80, 21),
          const Radius.circular(7),
        ),
        Paint()..color = ink,
      );
      text(
        canvas,
        '${game.coinsCollected} COINS',
        const Offset(300, 30),
        10,
        brass,
      );
    }
    final recoveryOpacity = game.infinite && !reducedMotion
        ? game.survival.recoveryOpacity
        : 1.0;
    final blink = recoveryOpacity < 1;
    if (blink) {
      canvas.saveLayer(
        const Rect.fromLTWH(0, 0, 360, 560),
        Paint()..color = Colors.white.withValues(alpha: recoveryOpacity),
      );
    }
    canvas.save();
    for (final gap in game.specialHazards.where(
      (h) => h.kind == HazardKind.platformGap && h.active,
    )) {
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(const Rect.fromLTWH(0, 0, 360, 560)),
          Path()..addRect(Rect.fromLTRB(gap.gapLeft, 0, gap.gapRight, 560)),
        ),
      );
    }
    paintInfiniteEnergy(canvas, game, reducedMotion);
    // Short, fading wake behind the ball. This never changes hit geometry.
    if (game.phase == GamePhase.playing && game.started) {
      final energy = (game.motionSpeed / 220).clamp(0.0, 1.0);
      final tint = Color.lerp(
        const Color(0xFF62E4D3),
        const Color(0xFFFFD27A),
        energy,
      )!;
      if (!reducedMotion) {
        for (final sample in game.ballTrail) {
          final fade = (1 - (game.clock - sample.time) / .2).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(sample.x, game.screenY(sample.y)),
            2 + 4 * fade,
            Paint()..color = tint.withValues(alpha: .24 * fade),
          );
        }
      }
      if (energy > .025) {
        final center = Offset(game.ballX, game.screenY(game.ballY));
        final radius = 15 + energy * 9;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                tint.withValues(alpha: reducedMotion ? .12 : .3),
                tint.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );
      }
    }
    if (game.infinite && game.survival.flash > 0 && !reducedMotion) {
      final t = 1 - game.survival.flash / .65;
      final center = Offset(game.ballX, game.screenY(game.ballY));
      for (var i = 0; i < 10; i++) {
        final angle = i * math.pi / 5;
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * (13 + 24 * t),
          1.8 * (1 - t),
          Paint()..color = brass.withValues(alpha: 1 - t),
        );
      }
    }
    final a = Offset(20, game.screenY(game.left)),
        b = Offset(340, game.screenY(game.right));
    canvas.drawLine(
      a + const Offset(0, 6),
      b + const Offset(0, 6),
      Paint()
        ..color = Colors.black.withAlpha(70)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF2C3A37)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a - const Offset(0, 1),
      b - const Offset(0, 1),
      Paint()
        ..color = palette.bar
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a - const Offset(0, 2.5),
      b - const Offset(0, 2.5),
      Paint()
        ..color = const Color(0xFFFFFFE8)
        ..strokeWidth = 1.2,
    );
    paintPlatformDetail(
      canvas,
      a,
      b,
      game.platformStyle,
      time: game.clock,
      reducedMotion: reducedMotion,
    );
    canvas.restore();
    paintGapWarning(canvas, game, reducedMotion);
    // Only two-finger play grabs the ends, so only it wears grab handles. The
    // other controls keep slim caps that never read as something to drag.
    final grips =
        game.started &&
        !game.oneFinger &&
        !game.bottomControls &&
        !game.boardTilt;
    // Two-finger handles may hang below the playfield into the control strip,
    // so they are drawn after its clip ends; other controls' caps stay here.
    void paintEnds() {
      for (final p in [a, b]) {
        final grip = grips
            ? (viewport.gripCenter(
                        game,
                        p == a ? 0 : 1,
                        heldOffset: gripOffsets[p == a ? 0 : 1],
                      ) -
                      viewport.offset) /
                  viewport.scale
            : p;
        if (grips) {
          canvas.drawLine(
            p,
            grip,
            Paint()
              ..color = brass.withAlpha(180)
              ..strokeWidth = 2 / viewport.scale,
          );
          canvas.drawCircle(p, 3, Paint()..color = ink);
          canvas.drawCircle(p, 1.5, Paint()..color = brass);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: grip,
              width: grips ? 27 / viewport.scale : 12,
              height: grips ? 32 / viewport.scale : 19,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = ink,
        );
        canvas.drawCircle(grip, 2, Paint()..color = brass);
        if (grips) {
          for (final dy in [-7.0, 7.0]) {
            canvas.drawLine(
              grip + Offset(-6, dy) / viewport.scale,
              grip + Offset(6, dy) / viewport.scale,
              Paint()
                ..color = brass
                ..strokeWidth = 1.5,
            );
          }
        }
      }
    }

    if (!grips) paintEnds();
    if (game.merging) {
      final run = game.mergeRun;
      Offset segmentCenter(int i) {
        return Offset(
          reducedMotion ? game.visualX : run.segmentX(game.visualX, i),
          run.segmentY(game.screenY(game.visualY), i),
        );
      }

      for (var i = 1; i < run.segments.length; i++) {
        canvas.drawLine(
          segmentCenter(i - 1),
          segmentCenter(i),
          Paint()
            ..color = ink.withAlpha(85)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
      for (var i = run.segments.length - 1; i > 0; i--) {
        paintNumberOrb(
          canvas,
          segmentCenter(i),
          run.segments[i],
          run.segmentRadius(i),
          opacity: .65,
          match: i == run.segments.length - 1,
        );
      }
      paintNumberOrb(canvas, segmentCenter(0), run.head, MergeRun.ballRadius);
    }
    if (!game.merging && game.ballScale > 0) {
      final p = Offset(game.visualX, game.screenY(game.visualY));
      if (!reducedMotion)
        paintCosmeticTrail(
          canvas,
          p,
          Offset(game.velocity, -(game.leftSpeed + game.rightSpeed) / 2),
          7 * game.ballScale,
          game.cosmetic,
        );
      canvas.drawCircle(
        p + const Offset(2, 4),
        7 * game.ballScale,
        Paint()
          ..color = Colors.black38
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      paintCosmetic(
        canvas,
        p,
        7 * game.ballScale,
        game.cosmetic,
        time: game.clock,
        rotation: game.ballRotation,
        reducedMotion: reducedMotion,
        steelPalette: palette.ball,
      );
      paintInfiniteMagnet(canvas, game, reducedMotion);
      paintInfiniteShield(canvas, game, reducedMotion);
    }

    if (blink) canvas.restore();

    if (game.phase == GamePhase.sinking && !reducedMotion) {
      final t = (game.phaseTime / .7).clamp(0.0, 1.0);
      final p = Offset(game.captureX, game.screenY(game.captureY));
      final color = game.lastSuccess ? const Color(0xFFEEFFE4) : orange;
      canvas.drawCircle(
        p,
        12 + t * 35,
        Paint()
          ..color = color.withAlpha(((1 - t) * 200).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - t),
      );
      if (game.lastSuccess)
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          canvas.drawCircle(
            p + Offset(math.cos(a), math.sin(a)) * (15 + t * 50),
            2 * (1 - t),
            Paint()..color = color.withAlpha(((1 - t) * 255).round()),
          );
        }
    }
    canvas.restore();
    if (grips) paintEnds();
    for (final p in [
      Offset(7, top + 20),
      Offset(353, top + 20),
      const Offset(7, 540),
      const Offset(353, 540),
    ]) {
      canvas.drawCircle(p, 2.3, Paint()..color = brass);
      canvas.drawLine(
        p - const Offset(1.4, 0),
        p + const Offset(1.4, 0),
        Paint()
          ..color = ink
          ..strokeWidth = .8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.world != world ||
      oldDelegate.game != game ||
      reducedMotion != oldDelegate.reducedMotion ||
      showHud != oldDelegate.showHud ||
      fillWidth != oldDelegate.fillWidth;
}
