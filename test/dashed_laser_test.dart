import 'package:balance_arcade/hazards.dart';
import 'package:flutter_test/flutter_test.dart';

/// A live horizontal laser at y 300, stepped once so its window is open.
SpecialHazard laser({
  double dashLength = 0,
  double dashGap = 30,
  double dashSpeed = 0,
}) =>
    SpecialHazard(
      HazardKind.laser,
      x: 180,
      y: 300,
      warningSeconds: 0,
      liveSeconds: 10,
      motion: HazardMotion.stationary,
      orientation: LaserOrientation.horizontal,
      dashLength: dashLength,
      dashGap: dashGap,
      dashSpeed: dashSpeed,
    )..step(1 / 120, 0);

/// Whether a ball crossing the beam straight down at [x] is hit.
bool crossing(SpecialHazard h, double x) => h.hits(x, 280, x, 320);

void main() {
  test('a solid laser blocks the whole beam, as before', () {
    final solid = laser();
    expect(solid.dashed, isFalse);
    expect(solid.laserSegments(24, 336), [(24.0, 336.0)]);
    for (final x in [30.0, 102.0, 180.0, 330.0]) {
      expect(crossing(solid, x), isTrue);
    }
  });

  test('a dashed laser lets the ball through its gaps only', () {
    // Lit 24–84, 120–180, 216–276, 312–336; gaps 84–120 and 180–216.
    final dashed = laser(dashLength: 60, dashGap: 36);
    expect(dashed.laserSegments(24, 336).first, (24.0, 84.0));
    expect(crossing(dashed, 102), isFalse, reason: 'middle of a gap');
    expect(crossing(dashed, 198), isFalse, reason: 'middle of a gap');
    expect(crossing(dashed, 50), isTrue, reason: 'on a dash');
    expect(crossing(dashed, 150), isTrue, reason: 'on a dash');
    // The ball's own radius (7) reaches a dash's end from inside the gap.
    expect(crossing(dashed, 89), isTrue, reason: '5 units past a dash end');
  });

  test('dashes slide along the beam at their speed', () {
    final moving = laser(dashLength: 60, dashGap: 36, dashSpeed: 48);
    expect(crossing(moving, 102), isFalse);
    // Half a second later every dash has slid 24 units to the right.
    for (var i = 0; i < 59; i++) {
      moving.step(1 / 120, 0);
    }
    final first = moving.laserSegments(24, 336).first;
    expect(first.$1, closeTo(48, .01));
    expect(first.$2, closeTo(108, .01));
    expect(crossing(moving, 102), isTrue, reason: 'a dash moved into it');
  });
}
