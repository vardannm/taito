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

class MergeHole {
  MergeHole(this.x, this.y);
  final double x;
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
  static const fallingRadius = 15.0, holeRadius = 13.0;
  // Like Classic holes, the ball falls when its center enters the opening.
  static const holeContactRadius = 9.0;
  static const platformWidth = platformRight - platformLeft;
  static const maxSegments =
      1 + (platformWidth - 2 * ballRadius) ~/ segmentSpacing;
  final segments = <int>[2];
  final orbs = <NumberOrb>[];
  final holes = <MergeHole>[];
  int score = 0, highest = 2, lastChain = 0, collected = 0, lastMergeScore = 0;
  bool overflow = false, hitHole = false;
  double spawnTime = 0, flash = 0;
  String notice =
      'Merge matching numbers. Keep the middle ball clear of holes.';
  int get head => segments.first;
  int get tail => segments.last;
  double get length => 2 * ballRadius + (segments.length - 1) * segmentSpacing;
  bool get full => length + segmentSpacing > platformWidth;
  bool get nearlyFull => segments.length >= maxSegments - 2;
  bool get ended => overflow || hitHole;
  bool canMerge(int value) => segments.contains(value);
  double get speed => (30 + (highest.bitLength - 2) * 3.0).clamp(30.0, 66.0);

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
    return slots * segmentSpacing;
  }

  double get rightSpan {
    var slots = 0;
    for (var i = 1; i < segments.length; i++) {
      slots = math.max(slots, segmentSlot(i));
    }
    return slots * segmentSpacing;
  }

  double get minHeadX => ended && overflow
      ? (platformLeft + platformRight) / 2
      : platformLeft + ballRadius + leftSpan;
  double get maxHeadX => ended && overflow
      ? (platformLeft + platformRight) / 2
      : platformRight - ballRadius - rightSpan;
  double segmentX(double headX, int index) =>
      headX + segmentSlot(index) * segmentSpacing;

  void collect(int value) {
    if (ended) return;
    lastChain = lastMergeScore = 0;
    collected++;
    // Carry through every equal value, regardless of which side displays it.
    // Resolve all merges before checking whether the snake outgrew the bar.
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
    overflow = length > platformWidth;
    flash = .8;
    notice = overflow
        ? 'Your snake outgrew the platform. Merge matching numbers to stay short.'
        : lastChain > 1
        ? '$lastChain CHAIN!  +$lastMergeScore'
        : lastChain == 1
        ? 'MERGED ${formatMergeNumber(value)}'
        : full
        ? 'PLATFORM FULL — match a number to make room'
        : 'Collect ${formatMergeNumber(tail)} to start a chain';
  }

  void _row(double y) {
    // Three food choices and two holes per wave. One food matches the smallest
    // segment and sits in the middle ball's current travel range.
    final safeX = minHeadX + random.nextDouble() * (maxHeadX - minHeadX);
    final xs = <double>[safeX];
    for (var i = 1; i < 3; i++) {
      final choices = <double>[];
      for (var x = 36.0; x <= 324; x += 4) {
        if (xs.every((other) => (other - x).abs() >= 60)) choices.add(x);
      }
      xs.add(choices[random.nextInt(choices.length)]);
    }
    final limit = math.min(7, math.max(2, highest.bitLength));
    for (var i = 0; i < xs.length; i++) {
      final value = i == 0 ? tail : 1 << (1 + random.nextInt(limit));
      orbs.add(NumberOrb(xs[i], y + random.nextDouble() * 18, value));
    }
    final holeXs = <double>[];
    for (var i = 0; i < 2; i++) {
      final choices = <double>[];
      for (var x = 36.0; x <= 324; x += 4) {
        if ((x - safeX).abs() >= 40 &&
            holeXs.every((other) => (other - x).abs() >= 64)) {
          choices.add(x);
        }
      }
      final x = choices[random.nextInt(choices.length)];
      holeXs.add(x);
      holes.add(MergeHole(x, y + 64 + random.nextDouble() * 8));
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
    if (ended) return;
    flash = math.max(0, flash - dt);
    final travel = speed * dt;
    final contacts = <(double, NumberOrb?, MergeHole?)>[];
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
    for (final hole in holes) {
      final contact = _contact(
        ax,
        ay,
        bx,
        by,
        hole.x,
        hole.y,
        travel,
        holeContactRadius,
      );
      hole.y += travel;
      if (contact != null) contacts.add((contact, null, hole));
    }
    contacts.sort((a, b) {
      final order = a.$1.compareTo(b.$1);
      // A simultaneous hole takes priority over a pickup.
      if (order != 0) return order;
      if ((a.$3 != null) == (b.$3 != null)) return 0;
      return a.$3 != null ? -1 : 1;
    });
    for (final contact in contacts) {
      if (contact.$3 != null) {
        hitHole = true;
        notice = 'Your middle ball fell into a hole.';
        return;
      }
      collect(contact.$2!.value);
      orbs.remove(contact.$2);
      if (ended) return;
    }
    orbs.removeWhere((orb) => orb.y > 580);
    holes.removeWhere((hole) => hole.y > 580);
    spawnTime += dt;
    if (spawnTime >= 110 / speed) {
      spawnTime = 0;
      _row(42);
    }
  }
}
