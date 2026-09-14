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
  eclipse('Eclipse', 'Dark heart, luminous orbit', 1000, 0xFFEBA6D9, 0, 2.5);

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
  bool get glowing =>
      [neon, reactor, aurora, nebula, nova, eclipse].contains(this);
}

String formatBoost(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
