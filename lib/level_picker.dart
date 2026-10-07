import 'tutorial_spotlight.dart';
import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'levels.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';
import 'game.dart';

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
  });
  final bool tutorial;
  final bool allLevelsUnlocked;
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
  bool skipped = false;
  late ControlMode? control = widget.controlMode;
  int get selected => widget.selected;
  int get totalStars => widget.totalStars;
  Map<int, LevelRecord> get records => widget.records;
  String get controlLabel => control?.label ?? widget.controlLabel;
  bool unlocked(int number) =>
      widget.allLevelsUnlocked || ClassicLevels.isUnlocked(number, totalStars);
  ValueChanged<int> get onSelected => widget.onSelected;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      LayoutBuilder(
        builder: (context, bounds) {
          final columns = bounds.maxWidth < 360
              ? 3
              : bounds.maxWidth < 600
              ? 4
              : 6;
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
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
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: ink.withAlpha(180)),
                    ),
                ],
              ),
            ),
          );
          Widget grid(int first, int count) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 166 + 75 * (textScale - 1).clamp(0, 2),
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final number = first + index,
                    active = number == selected && this.unlocked(number),
                    spider = number >= 31;
                final unlocked = this.unlocked(number);
                final required = ClassicLevels.requiredStars(number);
                final record =
                    control != null && widget.recordForControl != null
                    ? widget.recordForControl!(number, control!)
                    : records[number] ?? const LevelRecord();
                return Semantics(
                  button: true,
                  enabled: unlocked,
                  label:
                      'Level $number: ${ClassicLevels.names[number - 1]}${spider ? ", spider territory" : ""}${unlocked ? "" : ", locked, needs $required stars; you have $totalStars"}',
                  child: Material(
                    key: number == 1 ? firstLevelKey : null,
                    color: active
                        ? ink
                        : spider
                        ? const Color(0xFFE5DAC7)
                        : const Color(0xFFFFFAEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: active ? brass : ink.withAlpha(55),
                        width: active ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('level-$number'),
                      onTap:
                          unlocked &&
                              (!widget.tutorial || skipped || number == 1)
                          ? () => onSelected(number)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$number'.padLeft(2, '0'),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  color: active ? brass : ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              number % 10 == 0
                                  ? ClassicLevels.finaleTitle(number)
                                  : ClassicLevels.names[number - 1],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.15,
                                color: active ? cream : ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (unlocked)
                              StarRow(record.starMask, size: 16, dark: active)
                            else
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: ink,
                              ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                !unlocked
                                    ? '$totalStars / $required STARS'
                                    : record.bestScore > 0
                                    ? 'PB ${record.bestScore}'
                                    : (number % 10 == 0
                                          ? 'FINALE'
                                          : 'UNPLAYED'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: active ? cream : ink.withAlpha(165),
                                ),
                              ),
                            ),
                            if (unlocked && record.bestTime != null)
                              Text(
                                formatRunTime(record.bestTime!),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: active ? cream : ink,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }, childCount: count),
            ),
          );
          return CustomScrollView(
            slivers: [
              heading(
                'Choose your challenge.',
                widget.tutorial && !skipped
                    ? ''
                    : widget.allLevelsUnlocked
                    ? 'All ${ClassicLevels.count} levels temporarily unlocked. $controlLabel records.'
                    : '$totalStars Classic stars · 2 more stars unlock each level. Stars are shared across controls and are not spent. $controlLabel records.',
              ),
              if (control != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode in ControlMode.values)
                          ChoiceChip(
                            key: ValueKey('level-control-${mode.name}'),
                            label: Text(mode.label),
                            selected: control == mode,
                            onSelected: (_) {
                              setState(() => control = mode);
                              widget.onControlChanged?.call(mode);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              grid(1, 30),
              heading(
                'The web · 31–50',
                'Spiders patrol the marked territories. Cross a boundary and they chase. Contact ends your run.',
              ),
              grid(31, 20),
              if (ClassicLevels.count > 50) ...[
                heading(
                  'More challenges · 51–${ClassicLevels.count}',
                  'New boards, new routes. Keep climbing.',
                ),
                grid(51, ClassicLevels.count - 50),
              ],
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
  );
}
