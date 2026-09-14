import 'dart:math' as math;

String formatMergeNumber(int value) {
  const suffixes = ['', 'k', 'm', 'b', 't', 'q'];
  var unit = 0;
  var divisor = 1;
  while (unit < suffixes.length - 1 && value >= divisor * 1024) {
    divisor *= 1024;
    unit++;
  }
  return '${value ~/ divisor}${suffixes[unit]}';
}

class NumberOrb {
  NumberOrb(this.x, this.y, this.value);
  final double x;
  double y;
  final int value;
}

class MergeGate {
  MergeGate(this.requiredValue, {this.y = -24, this.scoreAt = 400});
  final int requiredValue, scoreAt;
  double y;
}

/// Values stay sorted largest to smallest; their positions alternate around
/// the solid middle ball. Equal values merge across either side of the snake.
class MergeRun {
  MergeRun({int? seed}) : random = math.Random(seed) {
    for (final y in [90.0, 210.0, 330.0]) {
      _row(y);
    }
  }
  final math.Random random;
  static const platformLeft = 20.0, platformRight = 340.0;
  static const ballRadius = 12.0, segmentSpacing = 26.0;
  static const fallingRadius = 15.0, gateInterval = 400;
  static const platformWidth = platformRight - platformLeft;
  static const maxSegments =
      1 + (platformWidth - 2 * ballRadius) ~/ segmentSpacing;
  final segments = <int>[2];
  final orbs = <NumberOrb>[];
  final gates = <MergeGate>[];
  int score = 0, highest = 2, lastChain = 0, collected = 0, lastMergeScore = 0;
  int nextGateScore = gateInterval, gatesPassed = 0;
  int? rejectedValue, failedGate;
  double gateCooldown = 0;
  double spawnTime = 0, flash = 0;
  String notice =
      'Collect equal or smaller numbers. Dodge larger numbers. Beat each gate.';
  int get head => segments.first;
  int get tail => segments.last;
  // Long snakes compress instead of ending the run or trapping the head.
  double get spacing => segments.length <= maxSegments
      ? segmentSpacing
      : 260 / (segments.length - 1);
  double get length => 2 * ballRadius + (segments.length - 1) * spacing;
  bool get ended => rejectedValue != null || failedGate != null;
  bool canMerge(int value) => segments.contains(value);
  double get speed => (30 + (highest.bitLength - 2) * 3.0).clamp(30.0, 66.0);
  double get gateSpeed => speed + 12;
  int get pendingGates => math.max(
    0,
    (score - nextGateScore) ~/ gateInterval + (score >= nextGateScore ? 1 : 0),
  );
  int get upcomingGateValue =>
      gates.isNotEmpty ? gates.first.requiredValue : gateValueAt(nextGateScore);

  /// 400 score -> 64, 800 -> 128, 1200 -> 256, 16400 -> 4096.
  /// Scale with earned score, rather than doubling every 400 indefinitely.
  static int gateValueAt(int milestone) =>
      math.pow(2, math.max(1, (milestone ~/ 4).bitLength - 1)).toInt();

  // Fill each ring on both sides, reversing the first side on the next ring:
  // 0, -1, +1, +2, -2, -3, +3 ... gives [2, 16, 32, 8, 4].
  int segmentSlot(int index) {
    if (index == 0) return 0;
    final ring = (index + 1) ~/ 2;
    final left = ring.isOdd == index.isOdd;
    return left ? -ring : ring;
  }

  double get leftSpan {
    var slots = 0;
    for (var i = 1; i < segments.length; i++) {
      slots = math.max(slots, -segmentSlot(i));
    }
    return slots * spacing;
  }

  double get rightSpan {
    var slots = 0;
    for (var i = 1; i < segments.length; i++) {
      slots = math.max(slots, segmentSlot(i));
    }
    return slots * spacing;
  }

  double get minHeadX => platformLeft + ballRadius + leftSpan;
  double get maxHeadX => platformRight - ballRadius - rightSpan;
  double segmentX(double headX, int index) =>
      headX + segmentSlot(index) * spacing;

  void collect(int value) {
    if (ended) return;
    if (value > head) {
      rejectedValue = value;
      notice =
          '$value is larger than your main ball ($head). Dodge larger numbers.';
      return;
    }
    lastChain = lastMergeScore = 0;
    collected++;
    // Carry through every equal value, regardless of which side displays it.
    var match = segments.indexOf(value);
    while (match >= 0) {
      segments.removeAt(match);
      value *= 2;
      score += value;
      lastMergeScore += value;
      lastChain++;
      match = segments.indexOf(value);
    }
    segments.add(value);
    segments.sort((a, b) => b.compareTo(a));
    highest = math.max(highest, head);
    flash = .8;
    notice = lastChain > 1
        ? '$lastChain CHAIN!  +$lastMergeScore'
        : lastChain == 1
        ? 'MERGED ${formatMergeNumber(value)}'
        : 'Collect ${formatMergeNumber(tail)} to start a chain';
  }

  void _row(double y) {
    // Two safe choices and one dangerous larger number per wave. Keep the
    // matching pickup reachable and separate the danger so it can be dodged.
    final safeX = minHeadX + random.nextDouble() * (maxHeadX - minHeadX);
    final xs = <double>[safeX];
    for (var i = 1; i < 3; i++) {
      final choices = <double>[];
      for (var x = 36.0; x <= 324; x += 4) {
        if (xs.every((other) => (other - x).abs() >= 60)) choices.add(x);
      }
      xs.add(choices[random.nextInt(choices.length)]);
    }
    for (var i = 0; i < xs.length; i++) {
      final value = i == 0
          ? tail
          : i == 2
          ? head * (random.nextBool() ? 2 : 4)
          : math
                .pow(2, 1 + random.nextInt(math.max(1, head.bitLength - 1)))
                .toInt();
      orbs.add(NumberOrb(xs[i], y + random.nextDouble() * 18, value));
    }
  }

  double? _contact(
    double ax,
    double ay,
    double bx,
    double by,
    double x,
    double y,
    double travel,
    double radius,
  ) {
    final ox = ax - x, oy = ay - y;
    final dx = bx - ax, dy = by - ay - travel;
    final length = dx * dx + dy * dy;
    final c = ox * ox + oy * oy - radius * radius;
    if (c <= 0) return 0;
    if (length <= 0) return null;
    final dot = ox * dx + oy * dy, disc = dot * dot - length * c;
    if (disc < 0) return null;
    final t = (-dot - math.sqrt(disc)) / length;
    return t >= 0 && t <= 1 ? t : null;
  }

  void step(double dt, double ax, double ay, double bx, double by) {
    if (ended || !dt.isFinite || dt <= 0) return;
    flash = math.max(0, flash - dt);
    final travel = speed * dt;
    final contacts = <(double, NumberOrb?, MergeGate?)>[];
    for (final orb in orbs) {
      final contact = _contact(
        ax,
        ay,
        bx,
        by,
        orb.x,
        orb.y,
        travel,
        ballRadius + fallingRadius,
      );
      orb.y += travel;
      if (contact != null) contacts.add((contact, orb, null));
    }
    for (final gate in gates) {
      final from = ay - gate.y, to = by - (gate.y + gateSpeed * dt);
      const radius = ballRadius + 3;
      double? contact;
      if (from.abs() <= radius) {
        contact = 0;
      } else if (from > radius && to <= radius) {
        contact = (from - radius) / (from - to);
      } else if (from < -radius && to >= -radius) {
        contact = (-radius - from) / (to - from);
      }
      gate.y += gateSpeed * dt;
      if (contact != null) contacts.add((contact, null, gate));
    }
    contacts.sort((a, b) {
      final order = a.$1.compareTo(b.$1);
      // A gate check takes priority at exactly simultaneous contact.
      if (order != 0) return order;
      if ((a.$3 != null) == (b.$3 != null)) return 0;
      return a.$3 != null ? -1 : 1;
    });
    for (final contact in contacts) {
      if (contact.$3 != null) {
        final gate = contact.$3!;
        if (head <= gate.requiredValue) {
          failedGate = gate.requiredValue;
          notice =
              'Gate ${gate.requiredValue}: your main ball ($head) must be greater.';
          return;
        }
        gates.remove(gate);
        gatesPassed++;
        gateCooldown = 1.2;
        flash = .8;
        notice = 'GATE ${gate.requiredValue} CLEARED';
        continue;
      }
      collect(contact.$2!.value);
      orbs.remove(contact.$2);
      if (ended) return;
    }
    orbs.removeWhere((orb) => orb.y > 580);
    gateCooldown = math.max(0, gateCooldown - dt);
    if (score >= nextGateScore && gates.isEmpty && gateCooldown == 0) {
      gates.add(MergeGate(gateValueAt(nextGateScore), scoreAt: nextGateScore));
      nextGateScore += gateInterval;
    }
    spawnTime += dt;
    if (spawnTime >= 110 / speed) {
      spawnTime = 0;
      _row(42);
    }
  }
}
