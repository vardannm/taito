/// Designs share the same collision sphere; bonuses and magnets affect Infinite.
enum BallCosmetic {
  steel('Steel', 'Polished metal', 0, 0xFFE9EADF, 0, 0),
  coral('Coral', 'Warm enamel', 60, 0xFFFF876D, 0, .1),
  circuit('Circuit', 'Jade ceramic circuits', 120, 0xFF84CCC2, 0, .2),
  neon('Neon', 'Radiant energy sphere', 220, 0xFF73FFF0, 0, .35),
  obsidian('Obsidian', 'Faceted dark crystal', 450, 0xFF9D89C8, 6, .5),
  prism('Prism', 'Floating diamond', 650, 0xFFFFD671, 4, .75),
  reactor('Reactor', 'Orbiting futuristic core', 1250, 0xFF80C7FF, 6, 1),
  aurora('Aurora', 'Flowing polar light', 1800, 0xFF78EBB7, 0, 1.25),
  nebula('Nebula', 'A miniature star field', 3400, 0xFFBB8DF2, 0, 1.5),
  nova('Nova', 'A blazing stellar core', 6200, 0xFFFFBF60, 8, 2),
  eclipse('Eclipse', 'Dark heart, luminous orbit', 8200, 0xFFEBA6D9, 0, 2.5),
  pearl('Pearl', 'Lustrous rose nacre', 320, 0xFFF4CCDA, 0, .4),
  malachite('Malachite', 'Banded green stone', 900, 0xFF51BA8C, 0, .65),
  titanium('Titanium', 'Machined blue metal', 2500, 0xFF98B6CE, 6, 1.3),
  opal('Opal', 'Iridescent mineral fire', 4600, 0xFFB2F3E7, 0, 1.8),
  plasma('Plasma', 'Violet arcs and a soft wake', 10800, 0xFFC995FF, 0, 2.7),
  comet('Comet', 'Frozen core with a stardust trail', 11500, 0xFF83E4FF, 6, 3),
  quasar('Quasar', 'Rose-gold orbital sparks', 12500, 0xFFFFA8C6, 0, 3.25),
  singularity(
    'Singularity',
    'A gold halo around midnight glass',
    13500,
    0xFFFFDC87,
    0,
    3.5,
  ),
  aether(
    'Aether',
    'Platinum glass with rose-gold celestial rings',
    0,
    0xFFCCE8FF,
    0,
    4,
  ),
  phoenix(
    'Phoenix',
    'Ruby fire with a gold feather corona',
    0,
    0xFFFFAD70,
    0,
    4.75,
  ),
  chronosphere(
    'Chronosphere',
    'A sapphire timepiece in gilded crystal',
    0,
    0xFF71F0E5,
    0,
    5.5,
  ),
  genesis(
    'Genesis',
    'An iridescent universe blooming around a white core',
    0,
    0xFFF6B6F5,
    0,
    6.5,
  );

  const BallCosmetic(
    this.label,
    this.description,
    this.cost,
    this.color,
    this.sides,
    this.scoreBonus,
  );
  final String label, description;
  final int cost, color, sides;
  final double scoreBonus;

  /// Reserved for verified store purchases once billing is connected.
  bool get purchaseOnly => index >= aether.index;

  /// Permanent Infinite collection radius. Zero means contact collection only.
  double get magnetRadius => switch (this) {
    titanium => 21,
    eclipse => 30,
    plasma => 39,
    quasar => 51,
    singularity => 66,
    aether => 78,
    phoenix => 90,
    chronosphere => 105,
    genesis => 120,
    _ => 0,
  };
  String get magnetLabel => switch (this) {
    titanium => 'Small magnet',
    eclipse => 'Medium magnet',
    plasma => 'Strong magnet',
    quasar => 'Wide magnet',
    singularity => 'Large magnet',
    aether => 'Celestial magnet',
    phoenix => 'Radiant magnet',
    chronosphere => 'Quantum magnet',
    genesis => 'Ultimate magnet',
    _ => 'No built-in magnet',
  };
  bool get glowing => [
    neon,
    reactor,
    aurora,
    nebula,
    nova,
    eclipse,
    opal,
    plasma,
    comet,
    quasar,
    singularity,
    aether,
    phoenix,
    chronosphere,
    genesis,
  ].contains(this);
  bool get premium => index >= plasma.index;
}

/// Shop order, weakest first: coin gear by price, then store-only gear by
/// boost. Also ranks strength, so the shop never suggests a weaker ball.
final List<BallCosmetic> ballShopOrder = List.unmodifiable(
  [...BallCosmetic.values]..sort(
    (a, b) => a.purchaseOnly != b.purchaseOnly
        ? (a.purchaseOnly ? 1 : -1)
        : a.purchaseOnly
        ? a.scoreBonus.compareTo(b.scoreBonus)
        : a.cost.compareTo(b.cost),
  ),
);

String formatBoost(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
