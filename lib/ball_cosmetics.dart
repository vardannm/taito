/// Visual designs share the same collision sphere; bonuses affect Infinite points.
enum BallCosmetic {
  steel('Steel', 'Polished metal', 0, 0xFFE9EADF, 0, 0),
  coral('Coral', 'Warm enamel', 35, 0xFFFF876D, 0, .1),
  circuit('Circuit', 'Striped ceramic', 65, 0xFF84CCC2, 0, .2),
  neon('Neon', 'Radiant energy sphere', 100, 0xFF73FFF0, 0, .35),
  obsidian('Obsidian', 'Faceted dark crystal', 140, 0xFF9D89C8, 6, .5),
  prism('Prism', 'Floating diamond', 180, 0xFFFFD671, 4, .75),
  reactor('Reactor', 'Orbiting futuristic core', 240, 0xFF80C7FF, 6, 1),
  aurora('Aurora', 'Flowing polar light', 360, 0xFF78EBB7, 0, 1.25),
  nebula('Nebula', 'A miniature star field', 500, 0xFFBB8DF2, 0, 1.5),
  nova('Nova', 'A blazing stellar core', 700, 0xFFFFBF60, 8, 2),
  eclipse('Eclipse', 'Dark heart, luminous orbit', 1000, 0xFFEBA6D9, 0, 2.5),
  pearl('Pearl', 'Lustrous rose nacre', 120, 0xFFF4CCDA, 0, .4),
  malachite('Malachite', 'Banded green stone', 220, 0xFF51BA8C, 0, .65),
  titanium('Titanium', 'Machined blue metal', 420, 0xFF98B6CE, 6, 1.3),
  opal('Opal', 'Iridescent mineral fire', 650, 0xFFB2F3E7, 0, 1.8),
  plasma('Plasma', 'Violet arcs and a soft wake', 1250, 0xFFC995FF, 0, 2.7),
  comet('Comet', 'Frozen core with a stardust trail', 1500, 0xFF83E4FF, 6, 3),
  quasar('Quasar', 'Rose-gold orbital sparks', 1900, 0xFFFFA8C6, 0, 3.25),
  singularity(
    'Singularity',
    'A gold halo around midnight glass',
    2400,
    0xFFFFDC87,
    0,
    3.5,
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
  ].contains(this);
  bool get premium => index >= plasma.index;
}

String formatBoost(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
