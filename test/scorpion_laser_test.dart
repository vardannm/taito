import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/late_enemies.dart';

LateEnemyShot laser() => LateEnemyShot(
  kind: LateShotKind.laser,
  origin: (x: 180, y: 100),
  beamEnd: (x: 180, y: 500),
  velocity: (x: 0, y: 0),
  delay: 1,
  life: 1,
);

void main() {
  test('laser catches fast crossings along its full length and round ends', () {
    final beam = laser()..step(1.1);
    beam.step(.01);
    expect(beam.contact(100, 400, 260, 400), closeTo(69 / 160, 1e-8));
    expect(beam.contact(180, 510, 180, 510), 0);
    expect(beam.contact(180, 89, 180, 89), 0);
    expect(beam.contact(180, 512, 180, 512), isNull);
    expect(beam.contact(180, 87, 180, 87), isNull);
    expect(beam.contact(192, 250, 192, 450), isNull);
  });

  test('laser activation and expiration clip collision to the live time', () {
    final beam = laser()..step(.95);
    beam.step(.1);
    // Crossing before activation is harmless, despite ending in a live tick.
    expect(beam.contact(180, 300, 250, 300), isNull);
    expect(beam.contact(180, 300, 180, 300), closeTo(.5, 1e-8));
    beam.step(.9);
    beam.step(.1);
    // Crossing after expiry is also harmless.
    expect(beam.contact(250, 300, 180, 300), isNull);
    expect(beam.contact(180, 300, 180, 300), 0);
    beam.step(.1);
    expect(beam.contact(180, 300, 180, 300), isNull);
  });

  test(
    'aim reaches either side, horizontal aim, or the bottom without tracking',
    () {
      for (final target in [
        (x: 50.0, y: 420.0),
        (x: 310.0, y: 420.0),
        (x: 310.0, y: 160.0),
        (x: 180.0, y: 420.0),
        (x: 180.0, y: 160.0),
      ]) {
        final e = LateEnemyEncounter(
          kind: LateEnemyKind.scorpion,
          origin: (x: 180, y: 160),
          target: target,
        );
        final beam = e.shots.single;
        final tip = beam.beamEnd!;
        expect(tip.x.isFinite && tip.y.isFinite, isTrue);
        expect(tip.x, inInclusiveRange(24.0, 336.0));
        expect(tip.y, inInclusiveRange(42.0, 537.0));
        e.step(1.3, scrollDistance: 500);
        expect(beam.beamEnd, tip);
        expect(beam.position, e.origin);
      }
    },
  );
}
