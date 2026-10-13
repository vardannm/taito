/// Equipment changes point rewards, never platform movement or collision size.
enum PlatformStyle {
  classic('Original', 'Brushed ivory rail', 0, 0xFFECE7CF, 0),
  copper('Copperline', 'Warm copper and inset rivets', 80, 0xFFE5A376, .25),
  jade('Jade runner', 'Carved jade with gold seams', 160, 0xFF71CBA6, .5),
  ion('Ion drive', 'Electric blue light channels', 320, 0xFF78CBF8, .75),
  solar('Solar flare', 'A warm gold energy rail', 550, 0xFFFFC86B, 1),
  prism('Prism rail', 'Iridescent violet panels', 850, 0xFFCD9CEE, 1.5),
  carbon('Carbon', 'Woven graphite and silver', 240, 0xFF81969E, .65),
  pearl('Pearl inlay', 'Rose ceramic and polished gold', 460, 0xFFE5BBCE, .9),
  aurora('Aurora rail', 'Flowing mint light', 1100, 0xFF85F5C1, 1.75),
  plasma('Plasma rail', 'Violet energy channels', 1400, 0xFFBA9BFF, 2),
  celestial(
    'Celestial',
    'Blue crystal with drifting sparks',
    1800,
    0xFF8ADEFF,
    2.5,
  ),
  sovereign(
    'Sovereign',
    'Obsidian, gold and orbiting light',
    2300,
    0xFFFFD380,
    3,
  ),
  aether(
    'Aether bridge',
    'Platinum filigree and rose-gold starlight',
    0,
    0xFFCFEAFF,
    3.5,
  ),
  phoenix(
    'Phoenix forge',
    'Ruby enamel with flowing golden feathers',
    0,
    0xFFFFAB65,
    4,
  ),
  chrono(
    'Chrono relay',
    'Teal sapphire, precision gears and gold seams',
    0,
    0xFF83F1E0,
    4.5,
  ),
  genesis(
    'Genesis arc',
    'Iridescent crystal petals and luminous pearl',
    0,
    0xFFF4B6F0,
    5,
  );

  bool get energized => index >= aurora.index;
  bool get purchaseOnly => index >= aether.index;

  const PlatformStyle(
    this.label,
    this.description,
    this.cost,
    this.color,
    this.scoreBonus,
  );
  final String label, description;
  final int cost, color;
  final double scoreBonus;
}
