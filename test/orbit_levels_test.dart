import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';

void main() {
  test(
    'circle and oval paths remain still during warning and complete one orbit',
    () {
      for (final motion in [HazardMotion.circle, HazardMotion.oval]) {
        final hazard = SpecialHazard(
          HazardKind.movingHole,
          x: 180,
          y: 260,
          motion: motion,
          radiusX: 40,
          radiusY: 20,
          period: 4,
          warningSeconds: 2,
          liveSeconds: 6,
        );
        expect((hazard.x, hazard.y), (220, 260));
        hazard.step(2, 0);
        expect((hazard.x, hazard.y), (220, 260));
        hazard.step(1, 0);
        expect(hazard.x, closeTo(180, 1e-9));
        expect(
          hazard.y,
          closeTo(motion == HazardMotion.circle ? 300 : 280, 1e-9),
        );
        hazard.step(3, 0);
        expect(hazard.x, closeTo(220, 1e-9));
        expect(hazard.y, closeTo(260, 1e-9));
      }
    },
  );

  test(
    'horizontal and vertical laser collision agrees with the visible beam',
    () {
      for (final orientation in LaserOrientation.values) {
        final hazard = SpecialHazard(
          HazardKind.laser,
          x: 180,
          y: 260,
          orientation: orientation,
          motion: HazardMotion.stationary,
          warningSeconds: 1,
          liveSeconds: 3,
        );
        hazard.step(.5, 0);
        expect(hazard.hits(180, 260, 180, 260), isFalse);
        hazard.step(.6, 0);
        // Test a full active interval; a crossing during warning is harmless.
        hazard.step(.01, 0);
        if (orientation == LaserOrientation.horizontal) {
          expect(hazard.hits(80, 200, 80, 300), isTrue);
          expect(hazard.hits(180, 100, 180, 100), isFalse);
          expect(hazard.hits(10, 260, 10, 260), isFalse);
        } else {
          expect(hazard.hits(100, 80, 220, 80), isTrue);
          expect(hazard.hits(80, 260, 80, 260), isFalse);
        }
      }
    },
  );

  test('moving beams sweep into a stationary ball without tunneling', () {
    final h = SpecialHazard(
      HazardKind.laser,
      x: 180,
      y: 200,
      orientation: LaserOrientation.horizontal,
      motion: HazardMotion.vertical,
      radiusY: 50,
      period: 4,
      warningSeconds: 0,
    );
    h.step(1, 0);
    expect(h.hits(120, 225, 120, 225), isTrue);
    final v = SpecialHazard(
      HazardKind.laser,
      x: 150,
      y: 260,
      motion: HazardMotion.horizontal,
      radiusX: 50,
      period: 4,
      warningSeconds: 0,
    );
    v.step(1, 0);
    expect(v.hits(175, 120, 175, 120), isTrue);
  });

  test(
    'all 30 new levels have unique connected boards and safe motion envelopes',
    () {
      expect(ClassicLevels.count, 80);
      final seen = <String>{},
          motions = <HazardMotion>{},
          orientations = <LaserOrientation>{};
      for (var n = 51; n <= 80; n++) {
        final d = ClassicLevels.definition(n);
        expect(
          seen.add(d.holes.map((h) => '${h.x},${h.y},${h.target}').join(';')),
          isTrue,
        );
        expect(
          ClassicLevels.hasSafeRoutes(d.holes, []),
          isTrue,
          reason: 'Level $n',
        );
        expect(
          d.holes.where((h) => h.target > 0).map((h) => h.target).toList()
            ..sort(),
          List.generate(10, (i) => i + 1),
        );
        expect(d.hazards, isNotEmpty);
        for (final w in d.hazards) {
          motions.add(w.motion);
          if (w.kind == HazardKind.laser) orientations.add(w.orientation);
          for (final p in w.positions) {
            final target = d.holes.singleWhere((h) => h.target == p.target);
            final h = SpecialHazard(
              w.kind,
              x: p.x,
              y: p.y,
              motion: w.motion,
              orientation: w.orientation,
              radiusX: w.radiusX,
              radiusY: w.radiusY,
              phase: w.phase,
              period: w.period,
              warningSeconds: 0,
              liveSeconds: w.period + 1,
            );
            for (var step = 0; step < 240; step++) {
              h.step(w.period / 240, 0);
              expect(h.x, inInclusiveRange(24, 336));
              expect(h.y, inInclusiveRange(24, 490));
              if (w.kind == HazardKind.laser) {
                final clearance = w.orientation == LaserOrientation.horizontal
                    ? (h.y - target.y).abs()
                    : (h.x - target.x).abs();
                expect(clearance, greaterThan(32));
              } else {
                expect(
                  math.sqrt(
                    math.pow(h.x - target.x, 2) + math.pow(h.y - target.y, 2),
                  ),
                  greaterThan(32),
                );
              }
            }
          }
        }
      }
      expect(
        motions,
        containsAll([
          HazardMotion.circle,
          HazardMotion.oval,
          HazardMotion.horizontal,
          HazardMotion.vertical,
        ]),
      );
      expect(orientations, containsAll(LaserOrientation.values));
    },
  );
}
