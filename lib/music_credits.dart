import 'ui_audio.dart';
import 'package:flutter/material.dart';

const _musicCredit =
    'Soundtracks created for Rollrise with ElevenLabs Music.\n\n'
    'Classic levels 1–40: the opening level theme.\n'
    'Classic levels 41 onward: the later theme with reduced ticking percussion.\n'
    'Daily challenges use the opening theme.\n\n'
    'Three arrangements of one theme: Climb, Fast Climb, and Boss.\n\n'
    'Edited into synchronized loops with lighter bass, matched playback levels, '
    'and crossfades driven by gameplay speed and boss encounters.';

Future<void> showMusicCredits(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Music credits'),
    scrollable: true,
    content: const SelectableText(_musicCredit),
    actions: [
      TextButton(
        onPressed: uiAction(context, () => Navigator.of(context).pop()),
        child: const Text('Close'),
      ),
    ],
  ),
);
