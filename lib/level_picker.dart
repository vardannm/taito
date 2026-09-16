import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'levels.dart';
import 'rewards.dart';
import 'mastery_widgets.dart';

class LevelPicker extends StatelessWidget {
  const LevelPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.records = const {},
    this.totalStars = 0,
    this.controlLabel = 'Two-finger',
  });
  final int selected, totalStars;
  final Map<int, LevelRecord> records;
  final String controlLabel;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
                active =
                    number == selected &&
                    ClassicLevels.isUnlocked(number, totalStars),
                spider = number >= 31;
            final unlocked = ClassicLevels.isUnlocked(number, totalStars);
            final required = ClassicLevels.requiredStars(number);
            final record = records[number] ?? const LevelRecord();
            return Semantics(
              button: true,
              enabled: unlocked,
              label:
                  'Level $number: ${ClassicLevels.names[number - 1]}${spider ? ", spider territory" : ""}${unlocked ? "" : ", locked, needs $required stars; you have $totalStars"}',
              child: Material(
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
                  onTap: unlocked ? () => onSelected(number) : null,
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
                          const Icon(Icons.lock_outline, size: 18, color: ink),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            !unlocked
                                ? '$totalStars / $required STARS'
                                : record.bestScore > 0
                                ? 'PB ${record.bestScore}'
                                : (number % 10 == 0 ? 'FINALE' : 'UNPLAYED'),
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
            '$totalStars Classic stars · 2 more stars unlock each level. Stars are shared across controls and are not spent. $controlLabel records.',
          ),
          grid(1, 30),
          heading(
            'The web · 31–50',
            'Spiders patrol the marked territories. Cross a boundary and they chase. Contact ends your run.',
          ),
          grid(31, 20),
        ],
      );
    },
  );
}
