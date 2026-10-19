import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Frosted control surfaces reveal the board beneath them.
class ControlGlass extends StatelessWidget {
  const ControlGlass({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(95)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withAlpha(40), Colors.white.withAlpha(12)],
          ),
        ),
        child: child,
      ),
    ),
  );
}
