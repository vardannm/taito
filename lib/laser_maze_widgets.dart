import 'package:flutter/material.dart';
import 'board_painter.dart';
import 'game.dart';
import 'laser_maze.dart';
import 'laser_maze_painter.dart';
import 'rewards.dart';

class LaserMazePicker extends StatelessWidget {
  const LaserMazePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.control,
    this.bestTimes = const {},
  });
  final int selected;
  final ControlMode control;
  final Map<int, double> bestTimes;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Laser Maze',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stay inside the red laser road and climb to the checkered finish. Touch a wall and the run ends.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    control == ControlMode.oneFinger
                        ? 'One finger: steer the tilt. The platform climbs automatically.'
                        : 'Lift both platform ends to climb. Tilt gently through each turn.',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '10 ROUTES · ${control.label.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, i) {
                final number = i + 1, active = number == selected;
                final best = bestTimes[number];
                return Semantics(
                  button: true,
                  label: 'Laser route $number: ${LaserMazeRoute.names[i]}',
                  child: Material(
                    color: active ? ink : const Color(0xFFFFFAEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: active ? orange : ink.withAlpha(45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('maze-route-$number'),
                      onTap: () => onSelected(number),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$number'.padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                    color: active ? cream : ink,
                                  ),
                                ),
                                const Spacer(),
                                if (best != null)
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 17,
                                    color: active ? brass : ink,
                                  ),
                              ],
                            ),
                            Expanded(
                              child: CustomPaint(
                                painter: MazeRoutePreview(number),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            Text(
                              LaserMazeRoute.names[i],
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? cream : ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              best == null
                                  ? 'REACH THE FINISH'
                                  : 'BEST ${formatRunTime(best)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: active ? brass : ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }, childCount: LaserMazeRoute.count),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: bounds.maxWidth < 500 ? 2 : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 170 + 60 * (textScale - 1).clamp(0, 2),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class LaserMazeResult extends StatelessWidget {
  const LaserMazeResult({
    super.key,
    required this.game,
    required this.newBest,
    required this.onRetry,
    required this.onLevels,
    required this.onHome,
    this.onNext,
  });
  final BalanceGame game;
  final bool newBest;
  final VoidCallback onRetry, onLevels, onHome;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ink.withAlpha(242),
      borderRadius: BorderRadius.circular(20),
    ),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              game.won ? Icons.flag_rounded : Icons.bolt_rounded,
              size: 38,
              color: game.won ? brass : const Color(0xFFFF767B),
            ),
            const SizedBox(height: 10),
            Text(
              game.won ? 'Finish reached.' : 'Laser contact.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: cream,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ROUTE ${game.level} · ${game.mazeRun.route.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: brass),
            ),
            const SizedBox(height: 8),
            Text(
              game.won
                  ? '${newBest ? 'NEW BEST · ' : ''}${formatRunTime(game.elapsed)}'
                  : '${game.score}% reached. Stay between the red walls.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCAD5CD)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: brass,
                  foregroundColor: ink,
                ),
                onPressed: game.won ? onNext ?? onLevels : onRetry,
                child: Text(
                  game.won
                      ? (onNext != null ? 'NEXT ROUTE' : 'CHOOSE A ROUTE')
                      : 'RETRY ROUTE',
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (game.won)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'RETRY ROUTE',
                      style: TextStyle(color: brass),
                    ),
                  ),
                if (!game.won || onNext != null)
                  TextButton(
                    onPressed: onLevels,
                    child: const Text(
                      'ALL ROUTES',
                      style: TextStyle(color: brass),
                    ),
                  ),
                TextButton(
                  onPressed: onHome,
                  child: const Text(
                    'BACK TO CLUB',
                    style: TextStyle(color: Color(0xFFCAD5CD)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
