import 'dart:math' as math;
import 'menu_design.dart';
import 'tutorial_spotlight.dart';
import 'package:flutter/material.dart';
import 'levels.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';
import 'game.dart';
import 'control_layout.dart';

class LevelPicker extends StatefulWidget {
  const LevelPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.records = const {},
    this.totalStars = 0,
    this.controlLabel = 'One-finger',
    this.tutorial = false,
    this.onSkipTutorial,
    this.allLevelsUnlocked = false,
    this.controlMode,
    this.onControlChanged,
    this.recordForControl,
    this.haloJoystick = false,
  });
  final bool tutorial;
  final bool allLevelsUnlocked;
  final bool haloJoystick;
  final ControlMode? controlMode;
  final ValueChanged<ControlMode>? onControlChanged;
  final LevelRecord Function(int, ControlMode)? recordForControl;
  final VoidCallback? onSkipTutorial;
  final int selected, totalStars;
  final Map<int, LevelRecord> records;
  final String controlLabel;
  final ValueChanged<int> onSelected;
  @override
  State<LevelPicker> createState() => _LevelPickerState();
}

class _LevelPickerState extends State<LevelPicker> {
  final firstLevelKey = GlobalKey();
  final _firstRowKey = GlobalKey(), _scrollKey = GlobalKey();
  final _scroll = ScrollController();
  bool _placedAtProgress = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Highest level completed with any control, or 0 before the first win.
  int get lastWon {
    bool won(int number) => [
      records[number],
      if (widget.recordForControl != null)
        for (final mode in selectableControlModes)
          widget.recordForControl!(number, mode),
    ].any((record) => record != null && record.starMask & 1 != 0);
    for (var number = visibleCount; number > 0; number--) {
      if (won(number)) return number;
    }
    return 0;
  }

  /// Opens the road at the player's progress instead of level 1: the last
  /// won level sits just above the middle with the next one just below it.
  void _showProgress(double rowHeight) {
    final last = lastWon;
    final row = _firstRowKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = _scrollKey.currentContext?.findRenderObject() as RenderBox?;
    if (last <= 1 || row == null || viewport == null || !_scroll.hasClients) {
      return;
    }
    final firstTop =
        row.localToGlobal(Offset.zero, ancestor: viewport).dy + _scroll.offset;
    final next = last < visibleCount && unlocked(last + 1);
    final focus = firstTop + (last - 1) * rowHeight + rowHeight * (next ? 1 : .5);
    _scroll.jumpTo(
      (focus - viewport.size.height / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      ),
    );
  }
  bool skipped = false;
  late ControlMode? _preferredControl = widget.controlMode;
  late bool _haloJoystick = widget.haloJoystick;
  bool get wideControls =>
      !allowsOneFingerPad(MediaQuery.sizeOf(context).shortestSide);
  ControlMode? get control =>
      wideControls &&
          _preferredControl == ControlMode.oneFinger &&
          !_haloJoystick
      ? ControlMode.twoFinger
      : _preferredControl;
  int get selected => widget.selected;
  int get totalStars => widget.totalStars;
  Map<int, LevelRecord> get records => widget.records;
  String controlName(ControlMode mode) =>
      mode == ControlMode.oneFinger && (wideControls || _haloJoystick)
      ? 'Halo Joystick'
      : mode.label;
  String get controlLabel =>
      control == null ? widget.controlLabel : controlName(control!);
  bool unlocked(int number) =>
      widget.allLevelsUnlocked || ClassicLevels.isUnlocked(number, totalStars);
  int get visibleCount => widget.allLevelsUnlocked
      ? ClassicLevels.count
      : math.min(totalStars ~/ 2 + 4, ClassicLevels.count);

  ValueChanged<int> get onSelected => widget.onSelected;
  @override
  Widget build(BuildContext context) => MenuSurface(
    child: Stack(
      children: [
        LayoutBuilder(
          builder: (context, bounds) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final rowHeight = 166 + 65 * (textScale - 1).clamp(0.0, 2.0);
            if (!_placedAtProgress && !(widget.tutorial && !skipped)) {
              _placedAtProgress = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showProgress(rowHeight),
              );
            }
            Widget heading(String title, String subtitle) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: menuText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: menuMuted),
                      ),
                  ],
                ),
              ),
            );
            Widget road(int first, int count) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverFixedExtentList(
                itemExtent: rowHeight,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final number = first + index;
                  final open = unlocked(number);
                  final active = number == selected && open;
                  final required = ClassicLevels.requiredStars(number);
                  final record =
                      control != null && widget.recordForControl != null
                      ? widget.recordForControl!(number, control!)
                      : records[number] ?? const LevelRecord();
                  return SizedBox(
                    key: number == 1 ? _firstRowKey : null,
                    height: rowHeight,
                    child: CustomPaint(
                      painter: LevelRoadPainter(number, open: open),
                      child: Align(
                        alignment: Alignment(
                          math.sin((number - 1) * math.pi / 2) * .78,
                          0,
                        ),
                        child: SizedBox(
                          width: math.min(180, bounds.maxWidth - 70),
                          child: Semantics(
                            button: true,
                            enabled: open,
                            label:
                                'Level $number, $classicLevelCoinPrize coin completion prize${number >= 31 ? ", spider territory" : ""}${open ? "" : ", locked, needs $required stars; you have $totalStars"}',
                            child: Material(
                              key: number == 1 ? firstLevelKey : null,
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey('level-$number'),
                                borderRadius: BorderRadius.circular(28),
                                onTap:
                                    open &&
                                        (!widget.tutorial ||
                                            skipped ||
                                            number == 1)
                                    ? () => onSelected(number)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: number % 10 == 0 ? 72 : 64,
                                        height: number % 10 == 0 ? 72 : 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: active
                                              ? menuGold
                                              : open
                                              ? menuRaised
                                              : menuBackground,
                                          border: Border.all(
                                            color: active
                                                ? menuGold
                                                : open
                                                ? menuMint
                                                : menuLine,
                                            width: active ? 4 : 2,
                                          ),
                                          boxShadow: active
                                              ? [
                                                  BoxShadow(
                                                    color: menuGold.withAlpha(
                                                      45,
                                                    ),
                                                    blurRadius: 22,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        // Large system text must shrink to fit
                                        // the fixed circle, not spill out of it.
                                        padding: const EdgeInsets.all(6),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: open
                                              ? Text(
                                                  '$number'.padLeft(2, '0'),
                                                  style: TextStyle(
                                                    fontSize: 23,
                                                    fontWeight: FontWeight.w800,
                                                    fontFamily: 'sans-serif',
                                                    color: active
                                                        ? menuBackground
                                                        : menuText,
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .lock_outline_rounded,
                                                      size: 18,
                                                      color: menuMuted,
                                                    ),
                                                    Text(
                                                      '$number',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: menuMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Flexible(
                                        child: Text(
                                          '+$classicLevelCoinPrize COINS',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            backgroundColor: menuBackground,
                                            fontSize: 11,
                                            height: 1.2,
                                            color: menuGold,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (open)
                                        ColoredBox(
                                          color: menuBackground,
                                          child: StarRow(
                                            record.starMask,
                                            count: 4,
                                            size: 15,
                                            dark: true,
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          !open
                                              ? '$totalStars / $required STARS'
                                              : record.stars > 0 ||
                                                    record.attempts > 0
                                              ? '${record.stars}/4 STARS'
                                              : number % 10 == 0
                                              ? 'FINALE'
                                              : 'UNPLAYED',
                                          style: const TextStyle(
                                            backgroundColor: menuBackground,
                                            fontSize: 9,
                                            color: menuMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (open && record.bestTime != null)
                                        Text(
                                          formatRunTime(record.bestTime!),
                                          style: const TextStyle(
                                            backgroundColor: menuBackground,
                                            fontSize: 9,
                                            color: menuMuted,
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
                  );
                }, childCount: count),
              ),
            );
            return CustomScrollView(
              key: _scrollKey,
              controller: _scroll,
              slivers: [
                heading(
                  'Choose your challenge.',
                  widget.tutorial && !skipped
                      ? ''
                      : widget.allLevelsUnlocked
                      ? 'Development access. $controlLabel records.'
                      : '$totalStars Classic stars · 2 more stars unlock each level. Stars are shared across controls and are not spent. $controlLabel records.',
                ),
                if (control != null && (!widget.tutorial || skipped))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mode
                              in widget.allLevelsUnlocked
                                  // Developer builds keep the test modes.
                                  ? ControlMode.values
                                  : selectableControlModes)
                            ChoiceChip(
                              key: ValueKey('level-control-${mode.name}'),
                              label: Text(
                                controlName(mode),
                                style: TextStyle(
                                  color: control == mode
                                      ? menuBackground
                                      : menuText,
                                ),
                              ),
                              selected: control == mode,
                              onSelected: (_) {
                                setState(() {
                                  _preferredControl = mode;
                                  if (wideControls &&
                                      mode == ControlMode.oneFinger) {
                                    _haloJoystick = true;
                                  }
                                });
                                widget.onControlChanged?.call(mode);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                road(1, visibleCount),
              ],
            );
          },
        ),
        if (widget.tutorial && !skipped)
          TutorialSpotlight(
            message:
                'Level 1: reach glowing holes in order, 1–10. Avoid dark holes.',
            blockOutside: true,
            onSkip: () {
              widget.onSkipTutorial?.call();
              setState(() => skipped = true);
            },
            targets: (layer) {
              final rect = tutorialTarget(firstLevelKey, layer);
              return [if (rect != null) rect];
            },
          ),
      ],
    ),
  );
}

class LevelRoadPainter extends CustomPainter {
  const LevelRoadPainter(this.number, {required this.open});
  final int number;
  final bool open;
  @override
  void paint(Canvas canvas, Size size) {
    final nodeWidth = math.min(180.0, size.width - 30);
    double x(int n) =>
        size.width / 2 +
        math.sin((n - 1) * math.pi / 2) * .78 * (size.width - nodeWidth) / 2;
    final current = x(number), before = x(number - 1), after = x(number + 1);
    final path = Path()
      ..moveTo((before + current) / 2, 0)
      ..cubicTo(
        current,
        size.height * .15,
        current,
        size.height * .3,
        current,
        size.height * .5,
      )
      ..cubicTo(
        current,
        size.height * .7,
        current,
        size.height * .85,
        (current + after) / 2,
        size.height,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = menuRaised,
    );
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 15) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + 6, metric.length)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = open ? menuGold.withAlpha(130) : menuLine,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LevelRoadPainter old) =>
      old.number != number || old.open != open;
}
