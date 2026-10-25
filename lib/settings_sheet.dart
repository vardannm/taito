import 'package:flutter/material.dart';

import 'menu_design.dart';

/// A fixed close action and a horizontal dismissal, independent of scrolling.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.child});
  final Widget child;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  double _swipeDistance = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('settings-sheet'),
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (_) => _swipeDistance = 0,
    onHorizontalDragUpdate: (details) => _swipeDistance += details.delta.dx,
    onHorizontalDragEnd: (details) {
      if (_swipeDistance > 80 ||
          (_swipeDistance > 20 && details.velocity.pixelsPerSecond.dx > 650)) {
        Navigator.of(context).maybePop();
      }
      _swipeDistance = 0;
    },
    onHorizontalDragCancel: () => _swipeDistance = 0,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: MenuHeading(
                'Options',
                eyebrow: 'YOUR ARCADE. YOUR WAY.',
                trailing: MenuIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close settings',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    ),
  );
}
