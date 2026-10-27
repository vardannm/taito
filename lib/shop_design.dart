import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'infinite_coin_chip.dart';
import 'menu_design.dart';

/// A full-screen destination whose opening rectangle comes from the real
/// Shop control. The page keeps its final layout while its reveal is clipped.
class ShopRevealRoute extends PageRouteBuilder<void> {
  ShopRevealRoute({
    required Rect origin,
    required WidgetBuilder builder,
    required bool reducedMotion,
    String name = '/collection',
  }) : super(
         settings: RouteSettings(name: name),
         opaque: false,
         barrierDismissible: false,
         barrierColor: Colors.black.withAlpha(45),
         transitionDuration: reducedMotion
             ? Duration.zero
             : const Duration(milliseconds: 480),
         reverseTransitionDuration: reducedMotion
             ? Duration.zero
             : const Duration(milliseconds: 360),
         pageBuilder: (context, animation, secondaryAnimation) =>
             AnnotatedRegion<SystemUiOverlayStyle>(
               value: const SystemUiOverlayStyle(
                 statusBarColor: Colors.transparent,
                 statusBarIconBrightness: Brightness.light,
                 statusBarBrightness: Brightness.dark,
                 systemNavigationBarColor: menuBackground,
                 systemNavigationBarIconBrightness: Brightness.light,
               ),
               child: Scaffold(
                 backgroundColor: menuBackground,
                 body: builder(context),
               ),
             ),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             LayoutBuilder(
               builder: (context, bounds) => AnimatedBuilder(
                 animation: animation,
                 child: child,
                 builder: (context, child) {
                   final t = Curves.easeInOutCubic.transform(animation.value);
                   final full = Offset.zero & bounds.biggest;
                   final start = origin.overlaps(full)
                       ? origin.intersect(full)
                       : Rect.fromCenter(
                           center: full.center,
                           width: 48,
                           height: 48,
                         );
                   final rect = Rect.lerp(start, full, t)!;
                   final radius = BorderRadius.circular(16 * (1 - t));
                   return Stack(
                     children: [
                       Positioned.fromRect(
                         rect: rect,
                         child: DecoratedBox(
                           key: const ValueKey('shop-reveal-surface'),
                           decoration: BoxDecoration(
                             color: menuBackground,
                             borderRadius: radius,
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withAlpha(60),
                                 blurRadius: 24,
                               ),
                             ],
                           ),
                           child: ClipRRect(
                             borderRadius: radius,
                             child: OverflowBox(
                               alignment: Alignment.topLeft,
                               minWidth: bounds.maxWidth,
                               maxWidth: bounds.maxWidth,
                               minHeight: bounds.maxHeight,
                               maxHeight: bounds.maxHeight,
                               child: Opacity(
                                 opacity: ((t - .08) / .72).clamp(0.0, 1.0),
                                 child: child,
                               ),
                             ),
                           ),
                         ),
                       ),
                     ],
                   );
                 },
               ),
             ),
       );
}

class ShopPurchaseButton extends StatelessWidget {
  const ShopPurchaseButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.equipped = false,
    this.price,
  });
  final Key? buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final bool equipped;

  /// A coin price leads the label with the painted coin.
  final int? price;
  @override
  Widget build(BuildContext context) => FilledButton(
    key: buttonKey,
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: menuGold,
      foregroundColor: menuBackground,
      disabledBackgroundColor: equipped ? const Color(0xFF233D39) : menuRaised,
      disabledForegroundColor: equipped ? menuMint : menuMuted,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      minimumSize: const Size(96, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (price != null) ...[
            const CoinIcon(size: 18),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            semanticsLabel: price == null ? null : '$label coins',
            style: const TextStyle(
              fontFamily: 'sans-serif',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

class ShopGalleryCard extends StatelessWidget {
  const ShopGalleryCard({
    super.key,
    required this.name,
    required this.description,
    required this.artwork,
    required this.action,
    required this.status,
    required this.detail,
    this.selected = false,
    this.artHeight = 188,
    this.footer,
  });
  final String name, description, status, detail;
  final Widget artwork, action;

  /// Shown under the price row, such as a way to get more coins.
  final Widget? footer;
  final bool selected;
  final double artHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: menuPanel,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: artHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: artwork),
                  Positioned(
                    left: 16,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: menuBackground.withAlpha(220),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: selected ? menuMint : menuText,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: menuText,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: menuMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          detail,
                          style: const TextStyle(
                            color: menuMint,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: action),
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: 6), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ShopPlatformStage extends CustomPainter {
  ShopPlatformStage(this.preview, {Listenable? animation})
    : super(repaint: animation);
  final CustomPainter preview;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDEE6D8), Color(0xFFACC5C0), Color(0xFF739497)],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(0, size.height * (.2 + i * .3)),
        Offset(size.width, size.height * (.05 + i * .3)),
        Paint()
          ..color = Colors.white.withAlpha(35)
          ..strokeWidth = 1,
      );
    }
    canvas.save();
    final scale = math.min(2.0, size.width / 160);
    canvas.scale(scale);
    preview.paint(canvas, Size(size.width / scale, size.height / scale));
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShopPlatformStage old) => old.preview != preview;
}
