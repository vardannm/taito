import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'infinite_coin_chip.dart';
import 'menu_design.dart';
import 'pickup_painter.dart';

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
    required this.artwork,
    required this.action,
    required this.status,
    this.boost,
    this.selected = false,
    this.artHeight = 250,
    this.footer,
    this.badge,
  });
  final String name, status;
  final Widget artwork, action;

  /// The Infinite points multiplier, such as '+1.3×'; null for base gear.
  final String? boost;

  /// Shown under the artwork, such as a way to get more coins.
  final Widget? footer;

  /// Pinned to the artwork's top right, such as a ball's magnet.
  final Widget? badge;
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
                  // A soft shade under the name and price keeps them readable
                  // on every world, light or dark.
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 130,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00081416), Color(0xB3081416)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 14,
                    child: ShopGlassPill(
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
                  if (badge != null)
                    Positioned(right: 16, top: 14, child: badge!),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.4,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              action,
                            ],
                          ),
                        ),
                        if (boost != null) ...[
                          const SizedBox(width: 12),
                          ShopBoostChip(boost: boost!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: footer!,
              ),
          ],
        ),
      ),
    ),
  );
}

/// A small frosted label that reads on any artwork behind it.
class ShopGlassPill extends StatelessWidget {
  const ShopGlassPill({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: menuBackground.withAlpha(170),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: child,
      ),
    ),
  );
}

/// The Infinite points multiplier: the endless mark and how much it adds.
class ShopBoostChip extends StatelessWidget {
  const ShopBoostChip({super.key, required this.boost});
  final String boost;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$boost Infinite points',
    excludeSemantics: true,
    child: ShopGlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '∞',
            style: TextStyle(
              color: menuGold,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            boost,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A ball's built-in Infinite magnet: the in-game magnet pickup, with its
/// pull radius under it.
class ShopMagnetBadge extends StatelessWidget {
  const ShopMagnetBadge({super.key, required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Magnet, radius ${radius.round()}',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 30,
          child: CustomPaint(painter: _MagnetIconPainter()),
        ),
        const SizedBox(height: 4),
        ShopGlassPill(
          child: Text(
            'RADIUS ${radius.round()}',
            style: const TextStyle(
              color: menuText,
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MagnetIconPainter extends CustomPainter {
  const _MagnetIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    // The pickup is drawn about 27 across; scale it to the badge.
    final scale = size.shortestSide / 27;
    canvas.scale(scale);
    paintPickup(
      canvas,
      Offset(size.width / 2 / scale, size.height / 2 / scale),
      PickupFace.magnet,
      0,
    );
  }

  @override
  bool shouldRepaint(_MagnetIconPainter old) => false;
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
