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

  /// Keep rewards on the board during attraction. The saved positions let
  /// collection use relative swept motion rather than an enlarged hit circle.
  Map<Object, ({double x, double y})> _pullInfiniteRewards(
    double dt,
    double oldX,
    double oldY,
  ) {
    final before = <Object, ({double x, double y})>{};
    ({double x, double y}) pull(Object reward, double x, double y) {
      before[reward] = (x: x, y: y);
      if (magnetRadius <= 0 ||
          circleContact(oldX, oldY, ballX, ballY, x, y, magnetRadius) == null)
        return (x: x, y: y);
      final dx = ballX - x, dy = ballY - y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance == 0) return (x: x, y: y);
      final travel = math.min(
        distance,
        (InfiniteTuning.magnetPullSpeed + distance * 3) * dt,
      );
      return (x: x + dx / distance * travel, y: y + dy / distance * travel);
    }

    for (final item in survival.items) {
      final at = pull(item, item.x, item.y);
      item.x = at.x;
      item.y = at.y;
    }
    for (final coin in coins.where((c) => !c.collected)) {
      final at = pull(coin, coin.x, coin.y);
      coin.x = at.x;
      coin.y = at.y;
    }
    return before;
  }

  void _pruneInfiniteSpiders() {
    spiders.removeWhere(
      (s) => screenY(s.zoneY) - s.zoneRadius > 620 && screenY(s.y) > 620,
    );
  }

  void _pruneInfinitePorcupines() {
    porcupines.removeWhere((p) => screenY(p.y) > 640);
  }

  void _updateSnakes(double dt) {
    if (!snakeEncountersEnabled ||
        mazeSection ||
        section == InfiniteSection.breath) {
      snakes.clear();
      _nextSnakeTime = math.max(_nextSnakeTime, elapsed + 2);
      return;
    }
    for (final snake in snakes) {
      snake.step(dt);
    }
    if (metres < InfiniteTuning.snakeUnlockMetres ||
        section != InfiniteSection.encounter ||
        elapsed < _nextSnakeTime ||
        snakes.isNotEmpty ||
        specialHazards.isNotEmpty ||
        webShots.isNotEmpty ||
        quills.isNotEmpty ||
        porcupines.any((p) => p.charge != null))
      return;
    final fromLeft = _random.nextBool();
    snakes.add(
      BoardSnake(
        x: fromLeft
            ? 65 + _random.nextDouble() * 35
            : 260 + _random.nextDouble() * 35,
        y: visibleTop - 28 - cameraOffset,
        fromLeft: fromLeft,
        phase: _random.nextDouble() * math.pi * 2,
        variant: _random.nextInt(3),
      ),
    );
    _nextSnakeTime =
        elapsed + InfiniteTuning.snakeInterval + _random.nextDouble() * 5;
  }

  void _spawnInfinitePorcupine(
    double y,
    double routeFrom,
    double routeTo,
    InfiniteSection stage,
  ) {
    if (y > _nextPorcupineY) return;
    _nextPorcupineY =
        y - InfiniteTuning.porcupineSpacing - _random.nextDouble() * 500;
    if (mazeSection ||
        stage == InfiniteSection.breath ||
        screenY(y) + 30 >= 0 ||
        porcupines.length >= InfiniteTuning.maxPorcupines)
      return;
    for (var attempt = 0; attempt < 24; attempt++) {
      final x = 52 + _random.nextDouble() * 256;
      if (x >= math.min(routeFrom, routeTo) - 65 &&
          x <= math.max(routeFrom, routeTo) + 65)
        continue;
      if (board.any(
            (h) => math.pow(h.x - x, 2) + math.pow(h.y - y, 2) < 44 * 44,
          ) ||
          spiders.any(
            (s) =>
                math.pow(s.zoneX - x, 2) + math.pow(s.zoneY - y, 2) <
                math.pow(s.zoneRadius + 85, 2),
          ))
        continue;
      porcupines.add(
        BoardPorcupine(x, y, heading: _random.nextDouble() * math.pi * 2),
      );
      return;
    }
  }

  void _updatePorcupines(double dt) {
    if (mazeSection || section == InfiniteSection.breath) {
      quills.clear();
      for (final p in porcupines) {
        p.charge = null;
      }
      _nextQuillTime = math.max(_nextQuillTime, elapsed + 1);
      return;
    }
    quills.removeWhere((q) => q.expired);
    for (final q in quills) {
      q.step(dt);
    }
    for (final p in porcupines) {
      final sy = screenY(p.y);
      // A committed warning may scroll below the attack-start zone before
      // completing. Keep it alive until the enemy actually leaves the board.
      if (sy < visibleTop + 32 || sy > BalanceGame.height + 30) {
        p.charge = null;
        continue;
      }
      if (p.charge != null) {
        p.charge = p.charge! + dt;
        if (p.charge! >= InfiniteTuning.quillWarningSeconds) {
          quills.addAll(p.burst());
          _nextQuillTime = elapsed + InfiniteTuning.quillInterval;
        }
        return;
      }
    }
    if (elapsed < _nextQuillTime ||
        snakes.isNotEmpty ||
        quills.isNotEmpty ||
        webShots.isNotEmpty ||
        specialHazards.isNotEmpty)
      return;
    for (final p in porcupines) {
      final sy = screenY(p.y);
      final distance = math.sqrt(
        math.pow(p.x - ballX, 2) + math.pow(p.y - ballY, 2),
      );
      final travelDuringWarning =
          (tutorialCourse ? tutorialAscent : ascentSpeed) *
          InfiniteTuning.quillWarningSeconds;
      if (sy < visibleTop + 32 ||
          sy > 430 ||
          sy + travelDuringWarning > BalanceGame.height - 20 ||
          distance < 85 ||
          distance > 330)
        continue;
      p.charge = 0;
      break;
    }
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
      if (porcupines.any(
        (p) =>
            math.pow(p.x - x, 2) + math.pow(p.y - y, 2) <
            math.pow(radius + 85, 2),
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
        snakes.isNotEmpty ||
        quills.isNotEmpty ||
        porcupines.any((p) => p.charge != null) ||
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
        SpiderWebShot(x: spider.x, y: spider.y, targetX: ballX, targetY: ballY),
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
            porcupines.any(
              (p) => math.pow(p.x - x, 2) + math.pow(p.y - atY, 2) < 42 * 42,
            ) ||
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
        final capped = survival.combo == InfiniteTuning.maxCombo;
        survival.combo = math.min(InfiniteTuning.maxCombo, survival.combo + 1);
        survival.bestCombo = math.max(survival.bestCombo, survival.combo);
        final points = capped
            ? InfiniteTuning.maxComboPickupPoints
            : (bonus * survival.combo).round();
        survival.points += points;
        survival.flash = .65;
        survival.announce(
          capped ? 'MAX COMBO  +$points' : 'COMBO x${survival.combo}  +$points',
        );
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
    final rewardStarts = _pullInfiniteRewards(dt, oldX, oldY);
    final events =
        <
          ({
            double t,
            InfiniteItem? item,
            BrassCoin? coin,
            Hole? hole,
            SpiderWebShot? web,
            PorcupineQuill? quill,
            String? reason,
          })
        >[];
    for (final snake in snakes) {
      final t = snake.contact(oldX, oldY, ballX, ballY);
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          quill: null,
          reason: 'Hit a snake. Dodge its slithering body.',
        ));
    }
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
          quill: null,
          reason: 'Caught by a spider. Stay outside its territory.',
        ));
    }
    _updatePorcupines(dt);
    for (final p in porcupines) {
      final t = circleContact(
        oldX,
        oldY,
        ballX,
        ballY,
        p.x,
        p.y,
        BalanceGame.ballRadius + BoardPorcupine.bodyRadius,
      );
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          quill: null,
          reason: 'Touched a porcupine. Keep clear of its quills.',
        ));
    }
    for (final q in quills) {
      final t = q.contact(oldX, oldY, ballX, ballY);
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: null,
          quill: q,
          reason: 'Hit by a porcupine quill. Dodge between the spikes.',
        ));
    }
    _updateSpiderWebs(dt);
    for (final web in webShots) {
      final t = web.contact(oldX, oldY, ballX, ballY);
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: null,
          web: web,
          quill: null,
          reason: 'Hit by a web. Dodge the aimed shot.',
        ));
    }
    // Rewards activate only when they reach the ball. A newly acquired magnet
    // starts pulling next tick, so a distant shield cannot protect retroactively.
    void queueRewards() {
      for (final item in survival.items) {
        final before = rewardStarts[item]!;
        final t = circleContact(
          oldX - before.x,
          oldY - before.y,
          ballX - item.x,
          ballY - item.y,
          0,
          0,
          13,
        );
        if (t != null)
          events.add((
            t: t,
            item: item,
            coin: null,
            hole: null,
            web: null,
            quill: null,
            reason: null,
          ));
      }
      for (final coin in coins.where((c) => !c.collected)) {
        final before = rewardStarts[coin]!;
        final t = circleContact(
          oldX - before.x,
          oldY - before.y,
          ballX - coin.x,
          ballY - coin.y,
          0,
          0,
          12,
        );
        if (t != null)
          events.add((
            t: t,
            item: null,
            coin: coin,
            hole: null,
            web: null,
            quill: null,
            reason: null,
          ));
      }
    }

    queueRewards();
    for (final hole in board) {
      final t = circleContact(oldX, oldY, ballX, ballY, hole.x, hole.y, 8.5);
      if (t != null)
        events.add((
          t: t,
          item: null,
          coin: null,
          hole: hole,
          web: null,
          quill: null,
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
          quill: null,
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
          quill: null,
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
        quill: null,
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
      } else if (contact.coin != null) {
        _takeCoin(contact.coin!);
      } else {
        if (contact.web != null) contact.web!.consumed = true;
        if (contact.quill != null) contact.quill!.consumed = true;
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
