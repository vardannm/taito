import 'menu_design.dart';
import 'package:flutter/material.dart';
import 'achievements.dart';
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
    return MenuSurface(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            MenuHeading(
              'Achievements',
              eyebrow: 'YOUR MILESTONES',
              trailing: MenuIconButton(
                icon: Icons.close,
                tooltip: 'Close achievements',
                onPressed: () => Navigator.pop(context),
              ),
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
                    ? const Color(0xFF2C4140)
                    : menuPanel,
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
                            color: menuGold,
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
                        color: menuGold,
                        backgroundColor: menuLine,
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
      ),
    );
  }
}
