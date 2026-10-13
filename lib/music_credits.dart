import 'package:flutter/material.dart';

const _musicCredit =
    'Music by Kevin MacLeod (incompetech.com)\n\n'
    'Infinite: “Furious Freak”\n'
    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1600021\n\n'
    '2048: “Dirt Rhodes”\n'
    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100542\n\n'
    'Licensed under Creative Commons Attribution 4.0\n'
    'https://creativecommons.org/licenses/by/4.0/\n\n'
    'Adapted for GILT: gameplay arrangements, loop crossfades, '
    'bass balance and playback level adjustment. '
    'Infinite also varies playback tempo with the run.';

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
