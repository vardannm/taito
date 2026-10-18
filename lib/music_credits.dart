import 'package:flutter/material.dart';

const _musicCredit =
    'Music by Kevin MacLeod (incompetech.com)\n\n'
    'Infinite: “The Complex”\n'
    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300025\n\n'
    'Licensed under Creative Commons Attribution 4.0\n'
    'https://creativecommons.org/licenses/by/4.0/\n\n'
    'Used in ROLLRISE with playback level adjustment and gradual playback tempo '
    'changes during Infinite. The original recording is otherwise unchanged.';

Future<void> showMusicCredits(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Music credits'),
    scrollable: true,
    content: const SelectableText(_musicCredit),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
