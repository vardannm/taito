part of 'game.dart';

extension InfiniteGameplay on BalanceGame {
  int get metres => (maxHeight / 10).floor();
  int get paceLevel => survival.levelAt(maxHeight / 10);
  double get pace => survival.paceAt(maxHeight / 10);

  double get magnetRadius => !infinite
      ? 0
      : math.max(
          cosmetic.magnetRadius,
          survival.magnet > 0 ? InfiniteTuning.magnetRadius : 0,
        );

  void _pruneInfiniteSpiders() {
    spiders.removeWhere(
      (s) => screenY(s.zoneY) - s.zoneRadius > 620 && screenY(s.y) > 620,
    );
  }

  void _spawnInfiniteSpider(
    double y,
    double routeFrom,
    double routeTo,
    InfiniteSection stage,
  ) {
    if (y > _nextSpiderY) return;
    // Distance-based encounters, with clear stretches between territories.
    // Consume skipped slots too, so maze/breath sections never build a backlog.
    _nextSpiderY =
        y -
        (1800 - 1200 * difficulty * InfiniteDifficulty.spiderGrowth) -
        _random.nextDouble() * 400;
    final radius = 38.0 + 2 * (paceLevel - 1) * InfiniteDifficulty.spiderGrowth;
    if (mazeSection ||
        stage == InfiniteSection.breath ||
        screenY(y) + radius >= 0 ||
        spiders.length >= 3)
      return;
    for (var attempt = 0; attempt < 24; attempt++) {
      final x = 52 + _random.nextDouble() * 256;
      // Protect both ends of the winding route through this row.
      if (x >= math.min(routeFrom, routeTo) - radius - 46 &&
          x <= math.max(routeFrom, routeTo) + radius + 46)
        continue;
      if (board.any(
        (h) =>
            math.pow(h.x - x, 2) + math.pow(h.y - y, 2) <
            math.pow(radius + 20, 2),
      ))
        continue;
      spiders.add(
        BoardSpider(
          x,
          y,
          radius,
          phase: _random.nextDouble() * math.pi * 2,
          chaseSpeed:
              InfiniteTuning.spiderChaseSpeed +
              InfiniteTuning.spiderChaseBonus *
                  (paceLevel - 1) *
                  InfiniteDifficulty.spiderGrowth,
        ),
      );
      return;
    }
  }

  void _updateSpiderWebs(double dt) {
    // Maze and breathing sections provide a clean break from ranged attacks.
    if (mazeSection || section == InfiniteSection.breath) {
      webShots.clear();
      _nextWebTime = math.max(_nextWebTime, elapsed + 1);
      return;
    }
    webShots.removeWhere((shot) => shot.expired);
    for (final shot in webShots) {
      shot.step(dt);
    }
    if (elapsed < _nextWebTime ||
        webShots.length >= InfiniteTuning.maxWebShots ||
        specialHazards.isNotEmpty)
      return;
    for (final spider in spiders) {
      final sy = screenY(spider.y);
      final dx = ballX - spider.x, dy = screenY(ballY) - sy;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (sy < visibleTop + 35 || sy > 490 || distance < 100 || distance > 300)
        continue;
      webShots.add(
        SpiderWebShot(
          x: spider.x,
          y: sy,
          targetX: ballX,
          targetY: screenY(ballY),
        ),
      );
      _nextWebTime = elapsed + InfiniteTuning.webInterval;
      break;
    }
  }

  void _ensureInfiniteItems() {
    final ahead = -cameraOffset + visibleTop - 100;
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
            spiders.any(
              (s) =>
                  math.pow(s.zoneX - x, 2) + math.pow(s.zoneY - atY, 2) <
                  math.pow(s.zoneRadius + 16, 2),
            ) ||
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
    while (survival.nextMagnetY >= ahead) {
      spawn(InfiniteItemKind.magnet, survival.nextMagnetY);
      survival.nextMagnetY -=
          InfiniteTuning.magnetSpacing + _random.nextDouble() * 1000;
    }
  }

  /// Starts, runs and ends a laser maze section. Gates are spaced by distance
  /// so their rhythm holds at any ascent speed, and the section is measured in
  /// points so it lasts the same stretch of the run however fast it is climbed.
  void _updateMazeSection(double dt) {
    for (final gate in mazeGates) {
      gate.step(dt, ascentSpeed);
    }
    mazeGates.removeWhere((gate) => gate.y > 600);
    _lastGateY += ascentSpeed * dt;
    final climbed = maxHeight / 10;
    if (!mazeSection) {
      if (!mazeSectionsEnabled || climbed < _nextMazeMetres) return;
      _mazeEndMetres = climbed + InfiniteTuning.mazeSectionMetres;
      _mazeSectionTime = 0;
      _lastGateY = 90;
      survival.announce('LASER MAZE · steer through the gaps');
      return;
    }
    _mazeSectionTime += dt;
    // Carry the hole generator's frontier along with the camera. The maze
    // stretch stays empty, and no backlog of rows bursts out when it ends.
    _nextRowY = math.min(_nextRowY, -cameraOffset - 121);
    if (climbed >= _mazeEndMetres ||
        _mazeSectionTime >= InfiniteTuning.mazeSectionSeconds) {
      _mazeEndMetres = 0;
      _nextMazeMetres =
          climbed + InfiniteTuning.mazeRestMetres + _random.nextDouble() * 260;
      // A beat of clear board before ordinary hazards resume.
      _nextHazardTime = math.max(_nextHazardTime, elapsed + 3);
      survival.announce('MAZE CLEARED');
      return;
    }
    if (_lastGateY < InfiniteTuning.mazeGateSpacing) return;
    _lastGateY = 0;
    // Wide by design: the opening only tightens a little as the pace rises.
    final width = (132 - 7.0 * (paceLevel - 1)).clamp(104.0, 132.0);
    final low = MazeGate.edge + width / 2 + 6;
    final high = MazeGate.edge + MazeGate.span - width / 2 - 6;
    // Each gap sits within reach of the last one, so no gate asks for a dash
    // the ball could not make in the time it has.
    final previous = mazeGates.isEmpty ? ballX : mazeGates.last.gapCenter;
    final from = math.max(low, previous - InfiniteTuning.mazeGapShift);
    final to = math.min(high, previous + InfiniteTuning.mazeGapShift);
    mazeGates.add(
      MazeGate(
        y: -30,
        gapCenter: from + _random.nextDouble() * math.max(0, to - from),
        gapWidth: width,
      ),
    );
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
      case InfiniteItemKind.magnet:
        survival.magnet = InfiniteTuning.magnetSeconds;
        survival.announce('MAGNET · 12 seconds of nearby rewards');
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

  void _resolveInfiniteContacts(
    double oldX,
    double oldY,
    double oldScreenY,
    double dt,
  ) {
    final events =
        <
          ({
            double t,
            InfiniteItem? item,
            BrassCoin? coin,
            Hole? hole,
            SpiderWebShot? web,
            String? reason,
          })
        >[];
    for (final spider in spiders) {
      final sx = spider.x, sy = spider.y;
      spider.step(dt, oldX, oldY, ballX, ballY);
      final t = circleContact(
        oldX - sx,
        oldY - sy,
        ballX - spider.x,
        ballY - spider.y,
        0,
        0,
        BalanceGame.ballRadius + spider.bodyRadius,
      );
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          reason: 'Caught by a spider. Stay outside its territory.',
        ));
    }
    _updateSpiderWebs(dt);
    for (final web in webShots) {
      final t = web.contact(oldX, oldScreenY, ballX, screenY(ballY));
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: web,
          reason: 'Hit by a web. Dodge the aimed shot.',
        ));
    }
    // Rebuild only future rewards when a magnet is picked up mid-sweep.
    // Earlier hazards stay earlier: a distant shield cannot protect retroactively.
    void queueRewards(double from) {
      events.removeWhere((e) => e.item != null || e.coin != null);
      final ax = oldX + (ballX - oldX) * from;
      final ay = oldY + (ballY - oldY) * from;
      for (final item in survival.items) {
        final t = circleContact(
          ax,
          ay,
          ballX,
          ballY,
          item.x,
          item.y,
          math.max(13, magnetRadius),
        );
        if (t != null)
          events.add((
            t: from + (1 - from) * t,
            item: item,
            coin: null,
            hole: null,
            web: null,
            reason: null,
          ));
      }
      for (final coin in coins.where((c) => !c.collected)) {
        final t = circleContact(
          ax,
          ay,
          ballX,
          ballY,
          coin.x,
          coin.y,
          math.max(12, magnetRadius),
        );
        if (t != null)
          events.add((
            t: from + (1 - from) * t,
            item: null,
            coin: coin,
            hole: null,
            web: null,
            reason: null,
          ));
      }
    }

    queueRewards(0);
    for (final hole in board) {
      final t = circleContact(oldX, oldY, ballX, ballY, hole.x, hole.y, 8.5);
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: hole,
          web: null,
          reason: 'Into a trap.',
        ));
    }
    for (final hazard in specialHazards) {
      final t = hazard.contact(
        oldX,
        oldScreenY,
        ballX,
        screenY(ballY),
        boardTop: visibleTop,
      );
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          reason: switch (hazard.kind) {
            HazardKind.laser => 'Laser hit. Move out of the blinking beam.',
            HazardKind.platformGap => 'The platform broke beneath you.',
            HazardKind.formingHole => 'The warning hole opened beneath you.',
            HazardKind.movingHole => 'Caught by a moving hole.',
          },
        ));
    }
    for (final gate in mazeGates) {
      final t = gate.contact(
        oldX,
        oldScreenY,
        ballX,
        screenY(ballY),
        BalanceGame.ballRadius,
      );
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          reason: 'Laser wall. Steer through the gap.',
        ));
    }
    if (ballY + BalanceGame.ballRadius >= dangerY) {
      events.add((
        t: 1,
        item: null,
        coin: null,
        hole: null,
        web: null,
        reason: 'The red caught you. Keep steering.',
      ));
    }
    // Resolve all rewards and hazards in travel order; ties favor rewards.
    while (events.isNotEmpty) {
      events.sort((a, b) {
        final order = a.t.compareTo(b.t);
        return order != 0
            ? order
            : (a.item != null || a.coin != null ? 0 : 1).compareTo(
                b.item != null || b.coin != null ? 0 : 1,
              );
      });
      final contact = events.removeAt(0);
      if (contact.item != null) {
        _takeInfiniteItem(contact.item!);
        if (contact.item!.kind == InfiniteItemKind.magnet) {
          queueRewards(contact.t);
        }
      } else if (contact.coin != null) {
        _takeCoin(contact.coin!);
      } else {
        if (contact.web != null) contact.web!.consumed = true;
        if (survival.protected) continue;
        fellThroughGap = contact.reason == 'The platform broke beneath you.';
        _loseClimb(contact.reason!, hole: contact.hole);
        if (phase != GamePhase.playing) return;
      }
    }
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
