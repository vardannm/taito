import 'dart:math' as math;

class NumberOrb {
  NumberOrb(this.x, this.y, this.value);
  final double x;
  double y;
  final int value;
}

/// Six-slot merge puzzle; all positions use the same 360 x 560 board as physics.
class MergeRun {
  MergeRun({int? seed}) : random = math.Random(seed) {
    for (final y in [90.0, 210.0, 330.0]) {
      _row(y);
    }
  }
  final math.Random random;
  final stack = <int>[2];
  final orbs = <NumberOrb>[];
  int score = 0, highest = 2, lastChain = 0, collected = 0, lastMergeScore = 0;
  bool overflow = false, continued = false;
  double spawnTime = 0, flash = 0;
  String notice = 'Match the top number. Six slots. Reach 2048.';
  int get top => stack.last;
  bool get won => highest >= 2048 && !continued && !overflow;
  bool get ended => overflow || won;
  double get speed => (30 + (highest.bitLength - 2) * 3.0).clamp(30.0, 66.0);

  void collect(int value) {
    if (ended) return;
    lastChain = lastMergeScore = 0;
    if (value != top && stack.length == 6) {
      overflow = true;
      notice = 'Stack full. You needed $top, but collected $value.';
      return;
    }
    collected++;
    // A match is allowed even with all six slots occupied.
    while (stack.isNotEmpty && stack.last == value) {
      stack.removeLast();
      value *= 2;
      score += value;
      lastMergeScore += value;
      lastChain++;
    }
    stack.add(value);
    highest = math.max(highest, value);
    flash = .8;
    notice = won
        ? '2048 reached! Keep building toward 4096.'
        : lastChain > 1
        ? '$lastChain CHAIN!  +$lastMergeScore'
        : lastChain == 1
        ? 'MERGED $value'
        : stack.length == 6
        ? 'FULL STACK — collect $top to make space'
        : 'Collect $top to merge';
  }

  void continueRun() {
    if (won) {
      continued = true;
      notice = 'Keep going. Next stop: 4096.';
    }
  }

  void _row(double y) {
    final xs = <double>[];
    // Three separated choices, each with independent placement and height.
    for (var i = 0; i < 3; i++) {
      double x = 48 + random.nextDouble() * 264;
      for (
        var attempt = 0;
        attempt < 60 && xs.any((v) => (v - x).abs() < 65);
        attempt++
      ) {
        x = 48 + random.nextDouble() * 264;
      }
      if (xs.any((v) => (v - x).abs() < 55)) continue;
      xs.add(x);
    }
    final match = random.nextInt(xs.length);
    final limit = math.min(7, math.max(2, highest.bitLength));
    for (var i = 0; i < xs.length; i++) {
      final value = i == match ? top : 1 << (1 + random.nextInt(limit));
      orbs.add(NumberOrb(xs[i], y + random.nextDouble() * 24, value));
    }
  }

  void step(double dt, double ax, double ay, double bx, double by) {
    if (ended) return;
    flash = math.max(0, flash - dt);
    final travel = speed * dt;
    final contacts = <(NumberOrb, double)>[];
    for (final orb in orbs) {
      final ox = ax - orb.x, oy = ay - orb.y;
      final dx = bx - ax, dy = by - ay - travel;
      orb.y += travel;
      final length = dx * dx + dy * dy;
      final c = ox * ox + oy * oy - 20 * 20;
      double? contact;
      if (c <= 0) {
        contact = 0;
      } else if (length > 0) {
        final dot = ox * dx + oy * dy, disc = dot * dot - length * c;
        if (disc >= 0) {
          final t = (-dot - math.sqrt(disc)) / length;
          if (t >= 0 && t <= 1) contact = t;
        }
      }
      if (contact != null) contacts.add((orb, contact));
    }
    contacts.sort((a, b) => a.$2.compareTo(b.$2));
    for (final contact in contacts) {
      collect(contact.$1.value);
      orbs.remove(contact.$1);
      if (ended) return;
    }
    orbs.removeWhere((orb) => orb.y > 580);
    spawnTime += dt;
    if (spawnTime >= 110 / speed) {
      spawnTime = 0;
      _row(42);
    }
  }
}
