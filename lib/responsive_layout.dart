import 'package:flutter/material.dart';

/// Phones retain their original full-width stage and menu dimensions.
bool usesWideStage(Size size) => size.width >= 600;

bool usesLandscapeMenu(Size size) =>
    size.width >= 1000 && size.width > size.height * 1.15;

double wideMenuScale(Size size) =>
    !usesWideStage(size) || size.height < 560 && !usesLandscapeMenu(size)
    ? 1
    : (size.shortestSide / 600).clamp(1.15, 1.5);

/// Scales the dimensions and type of a bounded piece of menu chrome together.
/// MediaQuery retains the real window size for device and control decisions.
class ScaledMenuChrome extends StatelessWidget {
  const ScaledMenuChrome({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1) return child;
    return LayoutBuilder(
      builder: (context, bounds) => OverflowBox(
        minWidth: bounds.maxWidth / scale,
        maxWidth: bounds.maxWidth / scale,
        minHeight: bounds.maxHeight / scale,
        maxHeight: bounds.maxHeight / scale,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}

/// Preserve the user's accessibility curve while increasing menu typography.
class WideMenuTextScaler extends TextScaler {
  const WideMenuTextScaler(this.parent, this.factor);
  final TextScaler parent;
  final double factor;

  @override
  double scale(double fontSize) => parent.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is WideMenuTextScaler &&
      other.parent == parent &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(parent, factor);
}
