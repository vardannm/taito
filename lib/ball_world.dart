import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ball_cosmetics.dart';
import 'ball_painter.dart';
import 'ball_world_scenery.dart';

/// One world per ball. These are visual settings only, never simulation inputs.
class BallWorld {
  const BallWorld(
    this.name,
    this.description,
    this.top,
    this.bottom,
    this.accent,
  );
  final String name, description;
  final Color top, bottom, accent;
  List<Color> get field => [top, Color.lerp(top, bottom, .5)!, bottom];
  Color get surround => Color.lerp(accent, const Color(0xFFF7F3EB), .88)!;
  bool get dark => top.computeLuminance() < .18;
  Color get ink => dark ? const Color(0xFFF0F6F5) : const Color(0xFF152F38);

  static BallWorld of(BallCosmetic ball) => switch (ball) {
    BallCosmetic.steel => const BallWorld(
      'Steel Atelier',
      'Midnight teal, soft light and brushed silver',
      Color(0xFF122B35),
      Color(0xFF244B52),
      Color(0xFF91C7C5),
    ),
    BallCosmetic.coral => const BallWorld(
      'Coral Lagoon',
      'Sunlit turquoise water and rose coral reefs',
      Color(0xFFC7EEE5),
      Color(0xFF5DA7AE),
      Color(0xFFF3A092),
    ),
    BallCosmetic.circuit => const BallWorld(
      'Circuit Garden',
      'Jade circuitry cut into a midnight garden',
      Color(0xFF092B32),
      Color(0xFF164B48),
      Color(0xFF93DBC0),
    ),
    BallCosmetic.neon => const BallWorld(
      'Neon City',
      'A violet city with cyan windows and rain-lit streets',
      Color(0xFF191F43),
      Color(0xFF4A426B),
      Color(0xFF6FE4E0),
    ),
    BallCosmetic.obsidian => const BallWorld(
      'Obsidian Cavern',
      'Violet crystal spires in volcanic stone',
      Color(0xFF181A32),
      Color(0xFF332448),
      Color(0xFFAD92E7),
    ),
    BallCosmetic.prism => const BallWorld(
      'Prism Palace',
      'Rose glass, sea-green facets and champagne edges',
      Color(0xFFF6E8D2),
      Color(0xFFD0C5D7),
      Color(0xFFBC976C),
    ),
    BallCosmetic.reactor => const BallWorld(
      'Reactor Station',
      'Orbital machinery inside a blue energy chamber',
      Color(0xFF101E30),
      Color(0xFF254655),
      Color(0xFF83DBEA),
    ),
    BallCosmetic.aurora => const BallWorld(
      'Polar Lights',
      'Silk ribbons above snowy mountain peaks',
      Color(0xFF10263A),
      Color(0xFF2B5967),
      Color(0xFF8DE1C4),
    ),
    BallCosmetic.nebula => const BallWorld(
      'Nebula Drift',
      'Violet clouds and distant constellations',
      Color(0xFF201D40),
      Color(0xFF443457),
      Color(0xFFCFA7EA),
    ),
    BallCosmetic.nova => const BallWorld(
      'Solar Forge',
      'Sun rays over a glowing molten horizon',
      Color(0xFF39223F),
      Color(0xFF965C51),
      Color(0xFFFFD291),
    ),
    BallCosmetic.eclipse => const BallWorld(
      'Moonlit Dunes',
      'A crescent moon over quiet rose dunes',
      Color(0xFF252439),
      Color(0xFF4E425F),
      Color(0xFFF0C4BE),
    ),
    BallCosmetic.pearl => const BallWorld(
      'Pearl Tides',
      'Nacre shells and soft rose ocean ripples',
      Color(0xFFF4EEE2),
      Color(0xFFB6D4D5),
      Color(0xFFBC929F),
    ),
    BallCosmetic.malachite => const BallWorld(
      'Emerald Grove',
      'Layered green stone and fern silhouettes',
      Color(0xFFB6DCCE),
      Color(0xFF549A89),
      Color(0xFF256B59),
    ),
    BallCosmetic.titanium => const BallWorld(
      'Titanium Foundry',
      'Cold alloy panels and industrial bracing',
      Color(0xFFD9E4E6),
      Color(0xFF93B1C0),
      Color(0xFF426781),
    ),
    BallCosmetic.opal => const BallWorld(
      'Opal Sanctuary',
      'Iridescent shards in a mint crystal landscape',
      Color(0xFFF2EDE1),
      Color(0xFFC4DADA),
      Color(0xFF8A98B5),
    ),
    BallCosmetic.plasma => const BallWorld(
      'Plasma Storm',
      'Violet lightning across an electric sky',
      Color(0xFF251C45),
      Color(0xFF51405C),
      Color(0xFFD9B0F9),
    ),
    BallCosmetic.comet => const BallWorld(
      'Comet Crossing',
      'Falling stardust above frozen ridgelines',
      Color(0xFF142C43),
      Color(0xFF366279),
      Color(0xFFACDFEA),
    ),
    BallCosmetic.quasar => const BallWorld(
      'Quasar Observatory',
      'Rose-gold starbursts and celestial orbits',
      Color(0xFF302840),
      Color(0xFF655064),
      Color(0xFFE4B99E),
    ),
    BallCosmetic.singularity => const BallWorld(
      'Event Horizon',
      'Golden stardust above distant midnight ridges',
      Color(0xFF101C2B),
      Color(0xFF2F3449),
      Color(0xFFE8C98A),
    ),
    BallCosmetic.aether => const BallWorld(
      'Aether Cathedral',
      'A floating cathedral beneath rose-gold celestial rings',
      Color(0xFF26364F),
      Color(0xFF526276),
      Color(0xFFF1D0B6),
    ),
    BallCosmetic.phoenix => const BallWorld(
      'Phoenix Ascendant',
      'Golden feather rays above a ruby volcanic horizon',
      Color(0xFF401D36),
      Color(0xFF864754),
      Color(0xFFFFCB82),
    ),
    BallCosmetic.chronosphere => const BallWorld(
      'Chrono Citadel',
      'Gilded clockwork and teal crystal towers',
      Color(0xFF113D49),
      Color(0xFF356564),
      Color(0xFFE9D28D),
    ),
    BallCosmetic.genesis => const BallWorld(
      'Genesis Bloom',
      'Opalescent ribbons and rose crystal gardens in deep space',
      Color(0xFF382B57),
      Color(0xFF665177),
      Color(0xFFF9CDE9),
    ),
  };
}

/// The same scenery is used on the board, in the shop and in world previews.
/// Coordinates are deterministic; no random state or gameplay clock is changed.
void paintBallWorld(
  Canvas canvas,
  Rect area,
  BallCosmetic ball, {
  double time = 0,
  bool reducedMotion = false,
  bool background = true,
  double energy = 0,
}) {
  final world = BallWorld.of(ball);
  canvas.save();
  canvas.clipRect(area);
  if (background) {
    canvas.drawRect(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: world.field,
        ).createShader(area),
    );
  }
  canvas.translate(area.left, area.top);
  canvas.scale(area.width / 340, area.height / 540);
  paintWorldScenery(canvas, ball, world.top, world.bottom, world.accent);
  canvas.restore();
}

/// Shop artwork shows the actual ball against its own world before purchase.
class BallWorldPreview extends CustomPainter {
  BallWorldPreview(this.ball, {this.animation}) : super(repaint: animation);
  final BallCosmetic ball;
  final Animation<double>? animation;
  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(10)));
    paintBallWorld(
      canvas,
      area,
      ball,
      time: (animation?.value ?? 0) * 12,
      reducedMotion: animation == null,
    );
    final p = size.center(Offset.zero);
    canvas.drawCircle(
      p + const Offset(0, 4),
      21,
      Paint()..color = Colors.black.withAlpha(28),
    );
    paintCosmetic(
      canvas,
      p,
      math.min(size.width, size.height) * .22,
      ball,
      time: (animation?.value ?? 0) * 12,
      reducedMotion: animation == null,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BallWorldPreview old) =>
      old.ball != ball || old.animation != animation;
}
