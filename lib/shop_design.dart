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
