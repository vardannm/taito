import 'dart:math' as math;
import 'package:balance_arcade/hazards.dart';
import 'package:balance_arcade/levels.dart';
import 'package:balance_arcade/infinite_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/classic_level_routes.dart';

void main() {
  test(
    'every target has a buffered launch route outside spider territories',
    () {
      for (var n = 1; n <= ClassicLevels.count; n++) {
        final level = ClassicLevels.definition(n);
        for (final target in level.holes.where((h) => h.target > 0)) {
          final route = routeToTarget(level, target);
          expect(
            route,
            isNotNull,
            reason: 'Level $n / target ${target.target}',
          );
          // Verify the whole route against the real swept-contact geometry.
          for (var i = 1; i < route!.length; i++) {
            final a = route[i - 1], b = route[i];
            for (final hole in level.holes) {
              if (identical(hole, target)) continue;
              expect(
                circleContact(a.$1, a.$2, b.$1, b.$2, hole.x, hole.y, 8.5),
                isNull,
                reason:
                    'Level $n / target ${target.target}: wrong hole on route',
              );
            }
            for (final spider in level.spiders) {
              expect(
                circleContact(
                  a.$1,
                  a.$2,
                  b.$1,
                  b.$2,
                  spider.x,
                  spider.y,
                  spider.zoneRadius + 7,
                ),
                isNull,
                reason:
                    'Level $n / target ${target.target}: territory on route',
              );
            }
          }
        }
      }
    },
  );

  test(
    'all warnings, quiet intervals and motion paths leave fair openings',
    () {
      for (var n = 1; n <= ClassicLevels.count; n++) {
        final level = ClassicLevels.definition(n);
        for (final wave in level.hazards) {
          expect(wave.warningSeconds, greaterThanOrEqualTo(2.4));
          expect(level.firstHazardAfter, greaterThanOrEqualTo(5));
          expect(
            level.hazardInterval - wave.warningSeconds - wave.liveSeconds,
            greaterThanOrEqualTo(1.2 - 1e-9),
            reason: 'Level $n has no quiet crossing',
          );
          expect(
            wave.positions.map((p) => p.target).toSet(),
            containsAll(List.generate(10, (i) => i + 1)),
          );
          for (final position in wave.positions) {
            final target = level.holes.singleWhere(
              (h) => h.target == position.target,
            );
            final hazard = SpecialHazard(
              wave.kind,
              x: position.x,
              y: position.y,
              motion: wave.motion,
              orientation: wave.orientation,
              radiusX: wave.radiusX,
              radiusY: wave.radiusY,
              period: wave.period,
              phase: wave.phase,
              warningSeconds: 0,
              liveSeconds: wave.period + 1,
            );
            // The complete envelope matters, including the phase used at spawn.
            for (var tick = 0; tick <= 240; tick++) {
              expect(hazard.x, inInclusiveRange(24, 336), reason: 'Level $n');
              expect(hazard.y, inInclusiveRange(24, 490), reason: 'Level $n');
              final clearance = wave.kind == HazardKind.laser
                  ? wave.orientation == LaserOrientation.horizontal
                        ? (hazard.y - target.y).abs()
                        : (hazard.x - target.x).abs()
                  : math.sqrt(
                      math.pow(hazard.x - target.x, 2) +
                          math.pow(hazard.y - target.y, 2),
                    );
              expect(
                clearance,
                greaterThan(32),
                reason:
                    'Level $n / target ${target.target}: unsafe moving path',
              );
              hazard.step(wave.period / 240, 0);
            }
          }
        }
        for (final spider in level.spiders) {
          for (final target in level.holes.where((h) => h.target > 0)) {
            expect(
              math.sqrt(
                math.pow(spider.x - target.x, 2) +
                    math.pow(spider.y - target.y, 2),
              ),
              greaterThanOrEqualTo(spider.zoneRadius + 24),
              reason: 'Level $n',
            );
          }
        }
      }
    },
  );

  test(
    'new mechanics get a clear introduction and return in later chapters',
    () {
      for (final n in [10, 20, 51, 56, 61, 66]) {
        final level = ClassicLevels.definition(n);
        expect(level.firstHazardAfter, greaterThanOrEqualTo(6));
        expect(level.hazards, hasLength(1));
        expect(level.hazards.single.warningSeconds, greaterThanOrEqualTo(2.8));
        expect(level.spiders, isEmpty);
      }
      // A skill should recur before a whole chapter passes without practice.
      var previousLaser = 10, previousMovingHole = 20, previousSpider = 31;
      for (var n = 10; n <= ClassicLevels.count; n++) {
        final level = ClassicLevels.definition(n);
        if (level.hazards.any((w) => w.kind == HazardKind.laser)) {
          expect(n - previousLaser, lessThanOrEqualTo(12));
          previousLaser = n;
        }
        if (level.hazards.any((w) => w.kind == HazardKind.movingHole)) {
          expect(n - previousMovingHole, lessThanOrEqualTo(14));
          previousMovingHole = n;
        }
        if (level.spiders.isNotEmpty) {
          expect(n - previousSpider, lessThanOrEqualTo(6));
          previousSpider = n;
        }
      }
      expect(
        ClassicLevels.definition(80).hazards.map((w) => w.motion).toSet(),
        containsAll([
          HazardMotion.circle,
          HazardMotion.oval,
          HazardMotion.horizontal,
          HazardMotion.vertical,
        ]),
      );
      expect(ClassicLevels.definition(80).spiders, hasLength(3));
    },
  );
}
