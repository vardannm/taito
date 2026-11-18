import 'ui_audio.dart';
import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// Menu and button color themes under evaluation. Only the static UI reads
/// these; ball worlds, boards and enemies keep their own colors.
enum UiTheme {
  deepTeal('Deep teal'),
  midnightIndigo('Midnight indigo'),
  slateSky('Slate sky'),
  plumDusk('Plum dusk'),
  cloudLight('Cloud light'),
  sandLight('Sand light');

  const UiTheme(this.label);
  final String label;

  static UiTheme named(String? name) =>
      values.where((t) => t.name == name).firstOrNull ?? deepTeal;
}

class UiPalette {
  const UiPalette({
    required this.background,
    required this.panel,
    required this.raised,
    required this.highlight,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.secondary,
    this.brightness = Brightness.dark,
  });
  final Color background, panel, raised, highlight, line, text, muted;
  final Color accent, onAccent, secondary;
  final Brightness brightness;

  static const themes = <UiTheme, UiPalette>{
    UiTheme.deepTeal: UiPalette(
      background: Color(0xFF0D171A),
      panel: Color(0xFF19282C),
      raised: Color(0xFF23363A),
      highlight: Color(0xFF2C4140),
      line: Color(0xFF34494D),
      text: Color(0xFFF6F0E3),
      muted: Color(0xFFA8BABD),
      accent: Color(0xFFE9C47C),
      onAccent: Color(0xFF0D171A),
      secondary: Color(0xFF82D9BE),
    ),
    UiTheme.midnightIndigo: UiPalette(
      background: Color(0xFF1C2140),
      panel: Color(0xFF282F57),
      raised: Color(0xFF313966),
      highlight: Color(0xFF3A4478),
      line: Color(0xFF3B4473),
      text: Color(0xFFF3F4FF),
      muted: Color(0xFFAEB4D9),
      accent: Color(0xFFFFB86B),
      onAccent: Color(0xFF1C2140),
      secondary: Color(0xFF8EC9FF),
    ),
    UiTheme.slateSky: UiPalette(
      background: Color(0xFF2A3242),
      panel: Color(0xFF364055),
      raised: Color(0xFF3E4A62),
      highlight: Color(0xFF465674),
      line: Color(0xFF4A5670),
      text: Color(0xFFF2F5FA),
      muted: Color(0xFFB3BCCC),
      accent: Color(0xFF5EC8FF),
      onAccent: Color(0xFF10202E),
      secondary: Color(0xFFFFD166),
    ),
    UiTheme.plumDusk: UiPalette(
      background: Color(0xFF2B2238),
      panel: Color(0xFF3B2F4E),
      raised: Color(0xFF45385A),
      highlight: Color(0xFF514268),
      line: Color(0xFF544468),
      text: Color(0xFFFBF3FF),
      muted: Color(0xFFC2B3D4),
      accent: Color(0xFFFF8FB1),
      onAccent: Color(0xFF2B1020),
      secondary: Color(0xFFB8A1FF),
    ),
    UiTheme.cloudLight: UiPalette(
      background: Color(0xFFEEF1F7),
      panel: Color(0xFFFFFFFF),
      raised: Color(0xFFF5F7FB),
      highlight: Color(0xFFE2E8FF),
      line: Color(0xFFD5DBE7),
      text: Color(0xFF1B2233),
      muted: Color(0xFF5D667A),
      accent: Color(0xFF4F6BFF),
      onAccent: Color(0xFFFFFFFF),
      secondary: Color(0xFFE8613F),
      brightness: Brightness.light,
    ),
    UiTheme.sandLight: UiPalette(
      background: Color(0xFFF5EFE6),
      panel: Color(0xFFFFFCF6),
      raised: Color(0xFFFBF6EE),
      highlight: Color(0xFFF7E4D3),
      line: Color(0xFFE3D8C6),
      text: Color(0xFF2E2A24),
      muted: Color(0xFF7A7062),
      accent: Color(0xFFD95F33),
      onAccent: Color(0xFFFFFFFF),
      secondary: Color(0xFF3E7BCB),
      brightness: Brightness.light,
    ),
  };
}

/// The theme the whole app currently paints its menus with.
UiTheme currentUiTheme = UiTheme.deepTeal;
UiPalette get uiPalette => UiPalette.themes[currentUiTheme]!;

Color get menuBackground => uiPalette.background;
Color get menuPanel => uiPalette.panel;
Color get menuRaised => uiPalette.raised;

/// A selected card or row, a step above [menuPanel].
Color get menuHighlight => uiPalette.highlight;
Color get menuLine => uiPalette.line;
Color get menuText => uiPalette.text;
Color get menuMuted => uiPalette.muted;

/// The main accent (buttons, icons, selection). Named for the original gold.
Color get menuGold => uiPalette.accent;
Color get menuOnAccent => uiPalette.onAccent;

/// The second accent. Named for the original mint.
Color get menuMint => uiPalette.secondary;

/// The home screen sits on the equipped ball's world, which is always dark
/// art, so light themes keep light ink and a dark shade there.
bool get _lightUi => uiPalette.brightness == Brightness.light;
Color get menuSceneryText => _lightUi ? const Color(0xFFF6F0E3) : menuText;
Color get menuSceneryMuted => _lightUi ? const Color(0xFFCBD3DA) : menuMuted;
Color get menuSceneryShade =>
    _lightUi ? const Color(0xFF151A26) : menuBackground;

/// Applies [theme] and rebuilds every widget, including ones and open
/// sheets, so the new colors reach the whole screen at once.
void applyUiTheme(UiTheme theme) {
  if (currentUiTheme == theme) return;
  currentUiTheme = theme;
  void rebuild(Element element) {
    element.markNeedsBuild();
    // Painters that never ask to repaint still read the new colors.
    if (element is RenderObjectElement) element.renderObject.markNeedsPaint();
    element.visitChildren(rebuild);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
}

ThemeData arcadeMenuTheme() {
  final light = uiPalette.brightness == Brightness.light;
  final base = light
      ? ThemeData.light(useMaterial3: true)
      : ThemeData.dark(useMaterial3: true);
  final scheme = light ? ColorScheme.light() : ColorScheme.dark();
  return base.copyWith(
    scaffoldBackgroundColor: menuBackground,
    colorScheme: scheme.copyWith(
      primary: menuGold,
      onPrimary: menuOnAccent,
      secondary: menuMint,
      onSecondary: menuOnAccent,
      surface: menuPanel,
      onSurface: menuText,
      outline: menuLine,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'sans-serif',
      bodyColor: menuText,
      displayColor: menuText,
    ),
    iconTheme: IconThemeData(color: menuGold),
    dividerTheme: DividerThemeData(color: menuLine, thickness: 1, space: 24),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: menuBackground,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: menuLine,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
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
        side: BorderSide(color: menuLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: menuGold,
        foregroundColor: menuOnAccent,
        disabledBackgroundColor: menuRaised,
        disabledForegroundColor: menuMuted,
        minimumSize: Size(48, 48),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: TextStyle(
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
        side: BorderSide(color: menuLine),
        minimumSize: Size(48, 48),
        textStyle: TextStyle(
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
        textStyle: TextStyle(
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
      side: BorderSide(color: menuLine),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontFamily: 'sans-serif',
        color: menuText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      hintStyle: TextStyle(color: menuMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: menuLine),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: menuMint,
      linearTrackColor: menuLine,
    ),
  );
}

class MenuSurface extends StatelessWidget {
  const MenuSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final factor = wideMenuScale(media.size);
    final scaler = media.textScaler;
    return MediaQuery(
      data: media.copyWith(
        textScaler: factor == 1 || scaler is WideMenuTextScaler
            ? scaler
            : WideMenuTextScaler(scaler, factor),
      ),
      child: Theme(
        data: arcadeMenuTheme(),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'sans-serif',
            color: menuText,
            fontSize: 14,
            height: 1.4,
          ),
          child: Material(
            color: menuBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            child: LayoutBuilder(
              builder: (context, bounds) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ((bounds.maxWidth - 960) / 2).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    padding: EdgeInsets.only(top: 10, bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[MenuSection(eyebrow!), SizedBox(height: 8)],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: menuText,
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) ...[SizedBox(width: 8), trailing!],
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: 10),
          Text(
            subtitle!,
            style: TextStyle(color: menuMuted, fontSize: 13, height: 1.45),
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
    style: TextStyle(
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
        colors: selected ? [menuHighlight, menuPanel] : [menuRaised, menuPanel],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? menuGold.withAlpha(180) : menuLine),
    ),
    child: child,
  );
}

/// Consistent navigation chrome for full-screen menus and the gear shop.
class MenuBackButton extends StatelessWidget {
  const MenuBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
    this.icon = Icons.arrow_back_rounded,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = usesWideStage(size);
    final scale = wideMenuScale(size);
    final extent = tablet ? (48 * scale).clamp(64.0, 72.0) : 48.0;
    final arrowSize = tablet ? (28 * scale).clamp(32.0, 36.0) : 21.0;
    return IconButton(
      tooltip: tooltip,
      onPressed: uiAction(context, onPressed, cue: UiCue.back),
      style: IconButton.styleFrom(
        minimumSize: Size.square(extent),
        maximumSize: Size.square(extent),
        foregroundColor: menuText,
      ),
      icon: Icon(icon, size: arrowSize),
    );
  }
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
    onPressed: uiAction(context, onPressed),
    style: IconButton.styleFrom(
      minimumSize: Size(44, 44),
      maximumSize: Size(44, 44),
      backgroundColor: menuPanel,
      foregroundColor: menuText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: menuLine),
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
  const MenuPill(this.text, {super.key, this.icon, this.leading, this.accent});
  final String text;
  final IconData? icon;

  /// Replaces [icon] with a custom mark, such as the painted coin.
  final Widget? leading;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? menuGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null || icon != null) ...[
            leading ?? Icon(icon, size: 16, color: accent),
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
        side: BorderSide(color: menuLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: uiAction(context, onTap),
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
                      style: TextStyle(
                        color: menuText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: menuMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  Icon(Icons.arrow_forward_rounded, size: 18, color: menuMuted),
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
                  style: TextStyle(fontSize: 11, color: menuMuted),
                ),
          value: value,
          onChanged: uiChange(context, onChanged),
        ),
      ),
    ),
  );
}

/// A 0-100 volume row matching the pause menu: the icon mutes and restores,
/// the slider sets the level, and [onChangeEnd] fires once the drag ends so
/// the caller can save.
/// Temporary picker for comparing menu themes. Each tile previews its own
/// palette: background, panel, accent button and second accent.
class UiThemePicker extends StatelessWidget {
  const UiThemePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final UiTheme value;
  final ValueChanged<UiTheme> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.maxWidth >= 520 ? 3 : 2;
      final width = (bounds.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final theme in UiTheme.values)
            SizedBox(
              width: width,
              child: _ThemeTile(
                theme: theme,
                selected: theme == value,
                onTap: () => onChanged(theme),
              ),
            ),
        ],
      );
    },
  );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });
  final UiTheme theme;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = UiPalette.themes[theme]!;
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme',
      child: Material(
        color: p.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('ui-theme-${theme.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: uiAction(context, onTap),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? p.accent : p.line,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: p.onAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: p.panel,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.muted.withAlpha(110),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: p.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: p.accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuVolumeSlider extends StatelessWidget {
  const MenuVolumeSlider({
    super.key,
    required this.name,
    required this.title,
    required this.icon,
    required this.mutedIcon,
    required this.level,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onToggleMute,
    this.subtitle,
  });
  final String name, title;
  final String? subtitle;
  final IconData icon, mutedIcon;

  /// Current level from 0 to 1.
  final double level;

  /// Levels from 0 to 1.
  final ValueChanged<double> onChanged, onChangeEnd;
  final VoidCallback onToggleMute;
  @override
  Widget build(BuildContext context) {
    final percent = (level * 100).round().clamp(0, 100);
    final on = percent > 0;
    final showSubtitle =
        subtitle != null &&
        !(MediaQuery.sizeOf(context).height < 650 &&
            MediaQuery.textScalerOf(context).scale(11) > 16.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MenuPanel(
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 2),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    key: ValueKey('settings-$name-mute'),
                    tooltip: '${on ? 'Mute' : 'Unmute'} $name',
                    color: on ? menuGold : menuMuted,
                    onPressed: uiAction(context, onToggleMute),
                    icon: Icon(on ? icon : mutedIcon),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showSubtitle)
                          Text(
                            subtitle!,
                            style: TextStyle(fontSize: 11, color: menuMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$percent',
                    key: ValueKey('settings-$name-value'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: on ? menuGold : menuMuted,
                    ),
                  ),
                ],
              ),
              Slider(
                key: ValueKey('settings-$name-slider'),
                value: percent.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: menuGold,
                inactiveColor: const Color(0x33FFFFFF),
                label: '$percent%',
                semanticFormatterCallback: (value) =>
                    '${value.round()} percent $name volume',
                onChanged: (value) => onChanged(value / 100),
                onChangeEnd: (value) => onChangeEnd(value / 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                        : BorderSide(color: menuLine),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: uiAction(
                      context,
                      () => onChanged(i),
                      cue: UiCue.select,
                    ),
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
        ..shader = LinearGradient(
          colors: [
            menuRaised,
            menuBackground,
            Color.lerp(menuBackground, Colors.black, .2)!,
          ],
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
