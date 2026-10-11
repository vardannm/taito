import 'package:flutter/material.dart';

const menuBackground = Color(0xFF0D171A);
const menuPanel = Color(0xFF19282C);
const menuRaised = Color(0xFF23363A);
const menuLine = Color(0xFF34494D);
const menuText = Color(0xFFF6F0E3);
const menuMuted = Color(0xFFA8BABD);
const menuGold = Color(0xFFE9C47C);
const menuMint = Color(0xFF82D9BE);

ThemeData arcadeMenuTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: menuBackground,
    colorScheme: const ColorScheme.dark(
      primary: menuGold,
      onPrimary: menuBackground,
      secondary: menuMint,
      onSecondary: menuBackground,
      surface: menuPanel,
      onSurface: menuText,
      outline: menuLine,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'sans-serif',
      bodyColor: menuText,
      displayColor: menuText,
    ),
    iconTheme: const IconThemeData(color: menuGold),
    dividerTheme: const DividerThemeData(
      color: menuLine,
      thickness: 1,
      space: 24,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: menuBackground,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: menuLine,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: menuPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: menuPanel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: menuLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: menuGold,
        foregroundColor: menuBackground,
        disabledBackgroundColor: menuRaised,
        disabledForegroundColor: menuMuted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: menuText,
        side: const BorderSide(color: menuLine),
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: menuGold,
        textStyle: const TextStyle(
          fontFamily: 'sans-serif',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: menuPanel,
      selectedColor: menuGold,
      disabledColor: menuPanel,
      side: const BorderSide(color: menuLine),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontFamily: 'sans-serif',
        color: menuText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? menuBackground : menuMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? menuMint : menuRaised,
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: menuGold,
      thumbColor: menuGold,
      inactiveTrackColor: menuLine,
      overlayColor: menuGold.withAlpha(24),
      trackHeight: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: menuBackground,
      hintStyle: const TextStyle(color: menuMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: menuLine),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: menuMint,
      linearTrackColor: menuLine,
    ),
  );
}

class MenuSurface extends StatelessWidget {
  const MenuSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: arcadeMenuTheme(),
    child: DefaultTextStyle(
      style: const TextStyle(
        fontFamily: 'sans-serif',
        color: menuText,
        fontSize: 14,
        height: 1.4,
      ),
      child: Material(
        color: menuBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: child,
      ),
    ),
  );
}

class MenuHeading extends StatelessWidget {
  const MenuHeading(
    this.title, {
    super.key,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? eyebrow, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          MenuSection(eyebrow!),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: menuText,
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: const TextStyle(
              color: menuMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ],
    ),
  );
}

class MenuSection extends StatelessWidget {
  const MenuSection(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: menuGold,
      fontSize: 10,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w800,
    ),
  );
}

class MenuPanel extends StatelessWidget {
  const MenuPanel({
    super.key,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final bool selected;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? [const Color(0xFF2C4140), menuPanel]
            : [menuRaised, menuPanel],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? menuGold.withAlpha(180) : menuLine),
    ),
    child: child,
  );
}

class MenuIconButton extends StatelessWidget {
  const MenuIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool badge;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
      backgroundColor: menuPanel,
      foregroundColor: menuText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: menuLine),
      ),
    ),
    icon: Badge(
      isLabelVisible: badge,
      backgroundColor: menuMint,
      child: Icon(icon, size: 20),
    ),
  );
}

class MenuPill extends StatelessWidget {
  const MenuPill(this.text, {super.key, this.icon, this.accent = menuGold});
  final String text;
  final IconData? icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: accent.withAlpha(14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withAlpha(60)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class MenuAction extends StatelessWidget {
  const MenuAction({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: menuPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: menuLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: menuGold.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: menuGold, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: menuText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(color: menuMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: menuMuted,
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MenuToggle extends StatelessWidget {
  const MenuToggle({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: MenuPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: menuGold),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle:
              subtitle == null ||
                  (MediaQuery.sizeOf(context).height < 650 &&
                      MediaQuery.textScalerOf(context).scale(11) > 16.5)
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 11, color: menuMuted),
                ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

class MenuTabs extends StatelessWidget {
  const MenuTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.minimal = false,
    this.icons,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool minimal;
  final List<IconData>? icons;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
      final columns = scale > 1.3 ? 2 : labels.length;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            SizedBox(
              width: (bounds.maxWidth - 6 * (columns - 1)) / columns,
              height: (icons == null ? 48 : 70) + 32 * (scale - 1).clamp(0, 2),
              child: Semantics(
                button: true,
                selected: i == selected,
                child: Material(
                  color: minimal
                      ? Colors.transparent
                      : i == selected
                      ? menuGold
                      : menuPanel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: minimal
                        ? BorderSide.none
                        : const BorderSide(color: menuLine),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Container(
                      decoration: minimal
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: i == selected
                                      ? menuGold
                                      : menuLine.withAlpha(80),
                                  width: i == selected ? 2 : 1,
                                ),
                              ),
                            )
                          : null,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (icons != null) ...[
                                Icon(
                                  icons![i],
                                  size: 22,
                                  color: i == selected ? menuGold : menuMuted,
                                ),
                                const SizedBox(height: 4),
                              ],
                              Flexible(
                                child: Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: minimal
                                        ? (i == selected ? menuGold : menuMuted)
                                        : i == selected
                                        ? menuBackground
                                        : menuText,
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: minimal
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class MenuBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF243D3F), menuBackground, Color(0xFF152429)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final lines = Paint()
      ..color = menuGold.withAlpha(13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [140.0, 200.0, 260.0]) {
      canvas.drawCircle(
        Offset(size.width + 25, size.height * .28),
        radius,
        lines,
      );
    }
    final grid = Path();
    for (var x = 0.0; x < size.width; x += 40) {
      grid.moveTo(x, 0);
      grid.lineTo(x, size.height);
    }
    canvas.drawPath(
      grid,
      Paint()
        ..color = menuText.withAlpha(4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(MenuBackdrop oldDelegate) => false;
}
