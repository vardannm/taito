import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'board_painter.dart';
import 'friend_challenge.dart';
import 'game.dart';
import 'next_goal.dart';
import 'playtest_recorder.dart';
import 'profile.dart';
import 'progress_backup.dart';
import 'rewards.dart';
export 'next_goal.dart';

class ClubScreen extends StatefulWidget {
  const ClubScreen({
    super.key,
    required this.profile,
    required this.onPlay,
    this.recorder,
  });
  final PlayerProfile profile;
  final void Function(GameMode, int, DateTime?) onPlay;
  final PlaytestRecorder? recorder;
  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final friends = <FriendChallenge>[];
  bool busy = false;
  PlayerProfile get profile => widget.profile;
  @override
  void initState() {
    super.initState();
    loadFriends();
  }

  Future<void> loadFriends() async {
    try {
      final codes =
          await profile.storage.getStringList('gilt.friends.v1') ?? [];
      final parsed = <FriendChallenge>[];
      for (final code in codes.take(30)) {
        try {
          parsed.add(FriendChallenge.decode(code));
        } catch (_) {
          /* Skip damaged codes. */
        }
      }
      if (mounted)
        setState(() {
          friends.addAll(parsed);
        });
    } catch (_) {
      if (mounted) notice('Friend records could not be loaded.');
    }
  }

  void notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> copy(String text, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      notice(message);
    } catch (_) {
      notice('Clipboard unavailable. Try again on your device.');
    }
  }

  Future<String?> textInput(String title, String hint, {int max = 1024}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: max,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
    // The dialog route still owns the field during its closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    return result;
  }

  Future<void> importFriend() async {
    final raw = await textInput(
      'Add a friend challenge',
      'Paste their GILT1 challenge code',
    );
    if (raw == null || !mounted) return;
    try {
      final friend = FriendChallenge.decode(raw);
      final updated = [
        ...friends.where(
          (f) =>
              !(f.name == friend.name &&
                  f.date == friend.date &&
                  f.control == friend.control),
        ),
        friend,
      ];
      final bounded = updated
          .skip((updated.length - 30).clamp(0, updated.length))
          .toList();
      await profile.storage.setStringList(
        'gilt.friends.v1',
        bounded.map((f) => f.encode()).toList(),
      );
      if (mounted)
        setState(() {
          friends
            ..clear()
            ..addAll(bounded);
        });
      notice('Challenge added. Play the same date and controls to compare.');
    } on FormatException catch (e) {
      notice(e.message);
    } catch (_) {
      notice('Could not save the challenge.');
    }
  }

  Future<void> shareDaily() async {
    final date = DailyChallenge.key(DateTime.now());
    final record = profile.dailyRecord(date);
    if (record.attempts == 0) {
      notice('Finish a Daily run with these controls first.');
      return;
    }
    final name = await textInput(
      'Name on your challenge',
      '1–24 letters, numbers, spaces, _ or -',
      max: 24,
    );
    if (name == null || !mounted) return;
    try {
      final challenge = FriendChallenge(
        name: name,
        date: date,
        control: profile.controlMode,
        score: record.bestScore,
      );
      FriendChallenge.decode(challenge.encode());
      await copy(challenge.encode(), 'Challenge copied. Send it to a friend.');
    } on FormatException {
      notice('Use 1–24 letters, numbers, spaces, _ or -.');
    }
  }

  Future<void> restore() async {
    final raw = await textInput(
      'Restore progress',
      'Paste your saved GILT progress backup',
      max: ProgressBackup.maxLength,
    );
    if (raw == null || !mounted) return;
    try {
      final candidate = ProgressBackup.decode(
        raw,
        testEconomy: profile.unlimitedCoins,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace this device’s progress?'),
          content: Text(
            'Backup: ${candidate.totalStars} stars, ${candidate.wallet} coins, Infinite best ${candidate.infiniteBest}m.\n\nCurrent: ${profile.totalStars} stars, ${profile.wallet} coins.\n\nThis replaces records, gear and settings. Copy your current backup first if you want to keep it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('RESTORE'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => busy = true);
      await ProgressBackup.restore(profile, candidate);
      notice('Progress restored.');
    } on FormatException catch (e) {
      notice(e.message);
    } catch (_) {
      notice(
        'Progress could not be saved completely. Keep your backup and retry.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void play(GameMode mode, int level, DateTime? date) {
    Navigator.pop(context);
    widget.onPlay(mode, level, date);
  }

  Widget section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final goal = NextGoal.forProfile(profile);
    final nextCabinet = CabinetStyle.values
        .where((c) => !profile.isUnlocked(c))
        .firstOrNull;
    final recorder = widget.recorder;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(title: const Text('Your arcade club')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              section('Your next goal', [
                Text(goal.title, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 6),
                Text(goal.detail),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: profile.totalStars / 150),
                Text('${profile.totalStars}/150 Classic stars'),
                if (nextCabinet != null)
                  Text(
                    '${nextCabinet.requiredStars - profile.totalStars} more stars unlock ${nextCabinet.title}.',
                  ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => play(goal.mode, goal.level, goal.date),
                  child: const Text('PLAY THIS GOAL'),
                ),
              ]),
              section('Daily with friends', [
                Text(
                  'Share a personal record for the same board and controls. These are friend-reported scores, saved on this device.',
                ),
                Text('Your controls: ${profile.controlMode.label}'),
                FilledButton.tonal(
                  onPressed: () => play(
                    GameMode.daily,
                    15,
                    DailyChallenge.day(DateTime.now()),
                  ),
                  child: const Text('PLAY TODAY’S DAILY'),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: shareDaily,
                      child: const Text('COPY MY CHALLENGE'),
                    ),
                    TextButton(
                      onPressed: importFriend,
                      child: const Text('ADD FRIEND CODE'),
                    ),
                  ],
                ),
                if (friends.isEmpty) const Text('No friend challenges yet.'),
                for (final friend in friends.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${friend.name} · ${friend.score} points'),
                    subtitle: Text(
                      '${friend.date} · ${friend.control.label}\nYour best: ${friend.yourScore(profile)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Play this challenge',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () {
                        profile.controlMode = friend.control;
                        play(
                          GameMode.daily,
                          15,
                          DateTime.parse('${friend.date}T00:00:00Z'),
                        );
                      },
                    ),
                  ),
              ]),
              section('Progress backup', [
                const Text(
                  'Copy your progress and save it somewhere you trust. Paste it on another device to restore. This is a manual backup; it does not sync automatically.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => copy(
                              ProgressBackup.encode(profile),
                              'Progress copied. Save the full text outside the game.',
                            ),
                      child: const Text('COPY BACKUP'),
                    ),
                    TextButton(
                      onPressed: busy ? null : restore,
                      child: const Text('RESTORE BACKUP'),
                    ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
              ]),
              if (recorder != null)
                section('Playtest session', [
                  const Text(
                    'Optional local observation for testing. Records control choice, starts, targets and results. No names and no uploads. Copy the report before closing the app.',
                  ),
                  Text(
                    '${recorder.active ? 'Recording' : 'Stopped'} · ${recorder.events.length} events',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          if (recorder.active) {
                            recorder.stop();
                          } else {
                            recorder.start();
                          }
                        }),
                        child: Text(
                          recorder.active
                              ? 'STOP SESSION'
                              : 'START NEW SESSION',
                        ),
                      ),
                      TextButton(
                        onPressed: recorder.events.isEmpty
                            ? null
                            : () => copy(
                                recorder.export(),
                                'Playtest report copied.',
                              ),
                        child: const Text('COPY REPORT'),
                      ),
                    ],
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
