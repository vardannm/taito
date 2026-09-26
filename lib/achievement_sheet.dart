import 'package:flutter/material.dart';
import 'achievements.dart';
import 'board_painter.dart';
import 'profile.dart';

class AchievementSheet extends StatefulWidget {
  const AchievementSheet({super.key, required this.profile});
  final PlayerProfile profile;

  @override
  State<AchievementSheet> createState() => _AchievementSheetState();
}

class _AchievementSheetState extends State<AchievementSheet> {
  bool busy = false;
  String? message;

  Future<void> claim(Achievement achievement) async {
    setState(() => busy = true);
    final paid = await widget.profile.claimAchievement(achievement);
    if (!mounted) return;
    setState(() {
      busy = false;
      message = paid
          ? '${achievement.coins} coins added to your wallet.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final earned = Achievement.values.where(p.achievementEarned).length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Achievements',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Close achievements',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '$earned of ${Achievement.values.length} earned',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Every run counts. Reach a milestone, then claim its coin reward. Your saved records count too.',
          ),
          const SizedBox(height: 12),
          if (message != null)
            Semantics(liveRegion: true, child: Text(message!)),
          if (!p.available)
            const Text(
              'Progress could not be saved on this device. Rewards are available for this session.',
            ),
          for (final a in Achievement.values) ...[
            const SizedBox(height: 12),
            Card(
              color: p.achievementEarned(a)
                  ? const Color(0xFFF2D99B)
                  : const Color(0xFFFFFAEE),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          p.achievementClaimed(a)
                              ? Icons.check_circle_rounded
                              : Icons.emoji_events_outlined,
                          color: ink,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.description),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: p.achievementProgress(a) / a.target,
                      color: ink,
                      backgroundColor: ink.withAlpha(25),
                      semanticsLabel: a.title,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${p.achievementProgress(a)} / ${a.target}  ·  ${a.coins} coins',
                    ),
                    if (p.achievementClaimed(a)) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'CLAIMED',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ] else if (p.achievementEarned(a)) ...[
                      const SizedBox(height: 8),
                      FilledButton(
                        key: ValueKey('claim-${a.name}'),
                        onPressed: busy ? null : () => claim(a),
                        child: Text('CLAIM ${a.coins} COINS'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
