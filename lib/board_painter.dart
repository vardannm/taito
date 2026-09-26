import 'ball_painter.dart';
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
import 'cabinet.dart';
import 'laser_maze_painter.dart';
import 'heart_loss_effect.dart';

const cream = Color(0xFFF2ECDD);
const ink = Color(0xFF163D3B);
const orange = Color(0xFFCD542F);
const brass = Color(0xFFD9AE65);

/// One transform shared by rendering and pointer hit testing.
class BoardViewport {
  BoardViewport(Size size, {double fillWidth = 0, double focusY = 440}) {
    final fit = math.min(
      size.width / BalanceGame.width,
      size.height / BalanceGame.height,
    );
    scale =
        fit +
        (size.width / BalanceGame.width - fit) * fillWidth.clamp(0.0, 1.0);
    final height = BalanceGame.height * scale;
    offset = Offset(
      (size.width - BalanceGame.width * scale) / 2,
      // Slack sits above the board during a run so it rests near the control
      // area instead of leaving a gap between the two.
      height <= size.height
          ? (size.height - height) *
                (.5 + .42 * fillWidth.clamp(0.0, 1.0))
          : (size.height * .72 - focusY * scale).clamp(
              size.height - height,
              0.0,
            ),
    );
  }
  factory BoardViewport.forGame(
    Size size,
    BalanceGame game, {
    double fillWidth = 0,
  }) => BoardViewport(
    size,
    fillWidth: fillWidth,
    focusY: game.screenY((game.left + game.right) / 2),
  );
  late final double scale;
  late final Offset offset;
  Offset project(Offset point) => offset + point * scale;
  Rect get rect =>
      offset & Size(BalanceGame.width * scale, BalanceGame.height * scale);
}

class BoardPainter extends CustomPainter {
  BoardPainter(
    this.game, {
    this.reducedMotion = false,
    this.fillWidth = 0,
    Listenable? repaint,
  }) : super(repaint: repaint);
  final BalanceGame game;
  final bool reducedMotion;
  final double fillWidth;

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
    final p = TextPainter(
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
    )..layout();
    p.paint(c, point - Offset(centered ? p.width / 2 : 0, p.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final palette = CabinetPalette.of(game.cabinet);
    final ink = palette.frame, brass = palette.trim;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final viewport = BoardViewport.forGame(size, game, fillWidth: fillWidth);
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.scale);
    final outer = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 360, 560),
      const Radius.circular(22),
    );
    canvas.drawRRect(outer, Paint()..color = ink);
    canvas.drawRRect(
      outer.deflate(2),
      Paint()
        ..color = brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final field = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 10, 340, 540),
      const Radius.circular(15),
    );
    canvas.drawRRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.field,
        ).createShader(field.outerRect),
    );
    canvas.save();
    canvas.clipRRect(field);
    paintInfiniteAtmosphere(canvas, game, reducedMotion);
    // Fine machined surface, concentric engraving, and calibrated side rails.
    final grain = Paint()
      ..color = const Color(0xFF533E20).withAlpha(13)
      ..strokeWidth = .45;
    for (double y = 12; y < 550; y += 4) {
      canvas.drawLine(Offset(10, y), Offset(350, y), grain);
    }
    final ring = Paint()
      ..color = ink.withAlpha(16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double r = 80; r < 460; r += 28) {
      canvas.drawCircle(const Offset(180, 270), r, ring);
    }
    text(
      canvas,
      'G',
      const Offset(180, 270),
      240,
      ink.withAlpha(9),
      weight: FontWeight.w900,
    );
    for (final x in [20.0, 340.0]) {
      canvas.drawLine(
        Offset(x, 26),
        Offset(x, 534),
        Paint()
          ..color = const Color(0xFF574A31)
          ..strokeWidth = 5,
      );
      canvas.drawLine(
        Offset(x - 1, 26),
        Offset(x - 1, 534),
        Paint()
          ..color = const Color(0xFFEEE7CC)
          ..strokeWidth = 1,
      );
      for (double y = 32; y < 530; y += 10) {
        canvas.drawLine(
          Offset(x == 20 ? 26 : 329, y),
          Offset(x == 20 ? 30 : 333, y),
          grain..color = ink.withAlpha(75),
        );
      }
    }
    if (game.maze)
      paintLaserMaze(
        canvas,
        game.mazeRun,
        game.clock,
        reducedMotion,
        cameraOffset: game.scrolling ? game.cameraOffset : 0,
      );
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
        text(canvas, '> ${gate.requiredValue}', Offset(180, gate.y), 15, cream);
      }
      if (game.mergeRun.flash > 0) {
        text(canvas, game.mergeRun.notice, const Offset(180, 28), 10, ink);
      }
    }
    paintSpiderBackdrop(canvas, game);
    final visibleHoles = game.board;
    for (final hole in visibleHoles) {
      final p = Offset(hole.x, game.screenY(hole.y));
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
    // Baseline and maker's mark remain below the hazards.
    if (!game.maze)
      text(
        canvas,
        'PRECISION IS EVERYTHING',
        const Offset(180, 545),
        6.5,
        ink.withAlpha(180),
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
          text(canvas, '${mark * 10}m', Offset(315, y), 7, ink.withAlpha(145));
          canvas.drawLine(
            Offset(30, y),
            Offset(42, y),
            Paint()
              ..color = ink.withAlpha(90)
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
      final r = reducedMotion
          ? 6.0
          : 6 + math.sin(game.clock * 3 + coin.x) * .5;
      canvas.drawCircle(
        p + const Offset(0, 1),
        r + 1,
        Paint()..color = const Color(0xFF604622),
      );
      canvas.drawCircle(p, r, Paint()..color = const Color(0xFFFFDA7B));
      canvas.drawCircle(
        p,
        r - 1.5,
        Paint()
          ..color = const Color(0xFF957034)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      canvas.drawLine(
        p - const Offset(0, 2.5),
        p + const Offset(0, 2.5),
        Paint()
          ..color = const Color(0xFF604622)
          ..strokeWidth = 1.5,
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
        ink,
      );
    }
    paintInfiniteItems(canvas, game, reducedMotion);
    paintSpecialHazards(canvas, game, reducedMotion);
    paintSpiders(canvas, game, reducedMotion);
    if (game.infinite) {
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
    if (game.infinite || game.mazeEndless) {
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
    paintPlatformDetail(canvas, a, b, game.platformStyle);
    canvas.restore();
    paintGapWarning(canvas, game, reducedMotion);
    for (final p in [a, b]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p,
            width: game.started ? 27 : 12,
            height: game.started ? 32 : 19,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = ink,
      );
      canvas.drawCircle(p, 2, Paint()..color = brass);
      if (game.started) {
        for (final dy in [-7.0, 7.0]) {
          canvas.drawLine(
            p + Offset(-6, dy),
            p + Offset(6, dy),
            Paint()
              ..color = brass
              ..strokeWidth = 1.5,
          );
        }
      }
    }
    if (game.merging) {
      final run = game.mergeRun;
      Offset segmentCenter(int i) {
        final x = run.segmentX(game.visualX, i);
        return Offset(x, game.screenY(game.platformY(x) - MergeRun.ballRadius));
      }

      if (run.segments.length > 1) {
        final leftX = game.visualX - run.leftSpan;
        final rightX = game.visualX + run.rightSpan;
        canvas.drawLine(
          Offset(
            leftX,
            game.screenY(game.platformY(leftX) - MergeRun.ballRadius),
          ),
          Offset(
            rightX,
            game.screenY(game.platformY(rightX) - MergeRun.ballRadius),
          ),
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
          MergeRun.ballRadius - 1,
          opacity: .38,
          match: i == run.segments.length - 1,
        );
      }
      paintNumberOrb(canvas, segmentCenter(0), run.head, MergeRun.ballRadius);
    }
    if (!game.merging && game.ballScale > 0) {
      final p = Offset(game.visualX, game.screenY(game.visualY));
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
        reducedMotion: reducedMotion,
        steelPalette: palette.ball,
      );
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
    for (final p in [
      const Offset(7, 20),
      const Offset(353, 20),
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
      oldDelegate.game != game ||
      reducedMotion != oldDelegate.reducedMotion ||
      fillWidth != oldDelegate.fillWidth;
}
