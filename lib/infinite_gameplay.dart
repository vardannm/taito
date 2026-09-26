part of 'game.dart';

extension InfiniteGameplay on BalanceGame {
  int get metres => (maxHeight / 10).floor();
  int get paceLevel => survival.levelAt(maxHeight / 10);
  double get pace => survival.paceAt(maxHeight / 10);

  void _ensureInfiniteItems() {
    final ahead = -cameraOffset - 100;
    void spawn(InfiniteItemKind kind, double y) {
      if (survival.items.length >= InfiniteTuning.maxItems) return;
      // Gold combo crystals sometimes sit near a hole, with a safe approach.
      final nearby = board.where((h) => (h.y - y).abs() < 90).toList();
      for (var attempt = 0; attempt < 36; attempt++) {
        double x = 48 + _random.nextDouble() * 264, atY = y;
        if (kind == InfiniteItemKind.combo &&
            nearby.isNotEmpty &&
            attempt < 4) {
          final h = nearby[_random.nextInt(nearby.length)];
          x = h.x + (_random.nextBool() ? 38 : -38);
          atY = h.y + 12;
        }
        if (x < 45 ||
            x > 315 ||
            board.any(
              (h) => math.pow(h.x - x, 2) + math.pow(h.y - atY, 2) < 32 * 32,
            ) ||
            survival.items.any(
              (item) =>
                  math.pow(item.x - x, 2) + math.pow(item.y - atY, 2) < 30 * 30,
            ) ||
            coins.any(
              (coin) =>
                  !coin.collected &&
                  math.pow(coin.x - x, 2) + math.pow(coin.y - atY, 2) < 24 * 24,
            ))
          continue;
        survival.items.add(InfiniteItem(kind, x, atY));
        return;
      }
    }

    while (survival.nextComboY >= ahead) {
      spawn(InfiniteItemKind.combo, survival.nextComboY);
      survival.nextComboY -=
          InfiniteTuning.comboSpacing + _random.nextDouble() * 140;
    }
    while (survival.nextShieldY >= ahead) {
      spawn(InfiniteItemKind.shield, survival.nextShieldY);
      survival.nextShieldY -=
          InfiniteTuning.shieldSpacing + _random.nextDouble() * 1400;
    }
    while (survival.nextHeartY >= ahead) {
      if (lives < InfiniteTuning.maxLives)
        spawn(InfiniteItemKind.heart, survival.nextHeartY);
      survival.nextHeartY -=
          InfiniteTuning.heartSpacing + _random.nextDouble() * 1800;
    }
  }

  void _takeInfiniteItem(InfiniteItem item) {
    survival.items.remove(item);
    final bonus = InfiniteTuning.comboPoints * paceLevel * survival.scoreBoost;
    switch (item.kind) {
      case InfiniteItemKind.combo:
        survival.combo = math.min(InfiniteTuning.maxCombo, survival.combo + 1);
        survival.bestCombo = math.max(survival.bestCombo, survival.combo);
        final points = (bonus * survival.combo).round();
        survival.points += points;
        survival.flash = .65;
        survival.announce('COMBO x${survival.combo}  +$points');
      case InfiniteItemKind.shield:
        survival.shield = InfiniteTuning.shieldSeconds;
        survival.announce('SHIELD · 10 seconds of invincibility');
      case InfiniteItemKind.heart:
        if (lives < InfiniteTuning.maxLives) {
          lives++;
          survival.announce('HEART RESTORED');
        } else {
          survival.points += (bonus * survival.combo).round();
          survival.announce(
            'FULL HEARTS · +${(bonus * survival.combo).round()}',
          );
        }
    }
    score = survival.points.floor();
    event = GameEvent.coin;
  }

  void _resolveInfiniteContacts(double oldX, double oldY, double oldScreenY) {
    final events =
        <({double t, InfiniteItem? item, Hole? hole, String? reason})>[];
    for (final item in survival.items) {
      final t = circleContact(oldX, oldY, ballX, ballY, item.x, item.y, 13);
      if (t != null) events.add((t: t, item: item, hole: null, reason: null));
    }
    for (final hole in board) {
      final t = circleContact(oldX, oldY, ballX, ballY, hole.x, hole.y, 8.5);
      if (t != null)
        events.add((t: t, item: null, hole: hole, reason: 'Into a trap.'));
    }
    for (final hazard in specialHazards) {
      final t = hazard.contact(oldX, oldScreenY, ballX, screenY(ballY));
      if (t != null)
        events.add((
          t: t,
          item: null,
          hole: null,
          reason: switch (hazard.kind) {
            HazardKind.laser => 'Laser hit. Move out of the blinking beam.',
            HazardKind.platformGap => 'The platform broke beneath you.',
            HazardKind.formingHole => 'The warning hole opened beneath you.',
            HazardKind.movingHole => 'Caught by a moving hole.',
          },
        ));
    }
    if (ballY + BalanceGame.ballRadius >= dangerY) {
      events.add((
        t: 1,
        item: null,
        hole: null,
        reason: 'The red caught you. Keep steering.',
      ));
    }
    // A shield protects only contacts reached after collection. Ties favor pickup.
    events.sort((a, b) {
      final order = a.t.compareTo(b.t);
      return order != 0
          ? order
          : (a.item != null ? 0 : 1).compareTo(b.item != null ? 0 : 1);
    });
    for (final contact in events) {
      if (contact.item != null) {
        _takeInfiniteItem(contact.item!);
      } else if (!survival.protected) {
        _collectCoins(
          oldX,
          oldY,
          oldX + (ballX - oldX) * contact.t,
          oldY + (ballY - oldY) * contact.t,
        );
        fellThroughGap = contact.reason == 'The platform broke beneath you.';
        _loseClimb(contact.reason!, hole: contact.hole);
        if (phase != GamePhase.playing) return;
      }
    }
    _collectCoins(oldX, oldY, ballX, ballY);
  }

  void _recoverInfinite() {
    survival.recovery = InfiniteTuning.recoverySeconds;
    // A nonfatal hit only grants protection. Position, momentum, the course
    // and active controller ownership keep advancing through the same run.
    fellThroughGap = false;
    survival.announce('LIFE LOST · Combo reset · $lives hearts left');
    message = survival.notice;
  }
}
