/// Equipment changes point rewards, never platform movement or collision size.
enum PlatformStyle {
  classic('Original', 'Brushed ivory rail', 0, 0xFFECE7CF, 0),
  copper('Copperline', 'Warm copper and inset rivets', 80, 0xFFE5A376, .25),
  jade('Jade runner', 'Carved jade with gold seams', 160, 0xFF71CBA6, .5),
  ion('Ion drive', 'Electric blue light channels', 320, 0xFF78CBF8, .75),
  solar('Solar flare', 'A warm gold energy rail', 550, 0xFFFFC86B, 1),
  prism('Prism rail', 'Iridescent violet panels', 850, 0xFFCD9CEE, 1.5);

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
