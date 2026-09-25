import 'dart:math' as math;
import 'game.dart';
import 'infinite_progress.dart';
import 'rewards.dart';

/// Stable, independently saved checkpoints. Feedback checkpoints prevent an
/// interrupted launch from asking the player to collect the same reward again.
enum TutorialStep {
  controls,
  heartsHoles,
  heartsFeedback,
  coins,
  coinsFeedback,
  shield,
  shieldFeedback,
  metrics,
  combo,
  comboFeedback,
  freePlay,
  shop,
  shopBall,
  shopPlatform,
  shopBrowse,
  levels,
  level1,
  classicPlay,
  dailyChallenge,
  completed;

  String get storageName => name.replaceAllMapped(
    RegExp('[A-Z]'),
    (match) => '_${match[0]!.toLowerCase()}',
  );
  bool get inInfinite => index <= freePlay.index;
  bool get scripted => index < freePlay.index;
  bool get inShop => index >= shop.index && index <= shopBrowse.index;
}

class TutorialProgress {
  TutorialProgress({
    this.step = TutorialStep.controls,
    this.freePlaySeconds = 0,
  });
  TutorialStep step;
  double freePlaySeconds;
  bool get active => step != TutorialStep.completed;
  bool get gameplayComplete => step.index >= TutorialStep.dailyChallenge.index;

  Map<String, Object> toJson() => {
    'step': step.storageName,
    'freePlaySeconds': freePlaySeconds,
  };

  factory TutorialProgress.fromJson(Map<String, dynamic> data) {
    final seconds = data['freePlaySeconds'];
    return TutorialProgress(
      step:
          TutorialStep.values
              .where((s) => s.storageName == data['step'])
              .firstOrNull ??
          TutorialStep.controls,
      freePlaySeconds: seconds is num && seconds.isFinite
          ? seconds.toDouble().clamp(0, 45)
          : 0,
    );
  }
}

/// Guides the real Infinite simulation; never fabricates collection events.
class TutorialRun {
  TutorialRun(this.game, this.progress, this.onChanged);
  final BalanceGame game;
  final TutorialProgress progress;
  final void Function() onChanged;
  double age = 0, initialHeight = 0;
  int initialCoins = 0, initialLives = 3;
  Hole? hole;
  BrassCoin? coin;
  InfiniteItem? pickup;

  void advance(TutorialStep step) {
    progress.step = step;
    configure();
    onChanged();
  }

  void configure() {
    age = 0;
    hole = null;
    coin = null;
    pickup = null;
    initialHeight = game.screenY((game.left + game.right) / 2);
    initialCoins = game.coinsCollected;
    initialLives = game.lives;
    final step = progress.step;
    if (!game.infinite || !step.scripted) {
      game.endTutorialCourse();
      return;
    }
    game.tutorialCourse = true;
    game.tutorialAscent = step == TutorialStep.controls ? 0 : 30;
    game.board.clear();
    game.coins.clear();
    game.survival.items.clear();
    game.specialHazards.clear();
    game.spiders.clear();
    game.porcupines.clear();
    game.snakes.clear();
    game.webShots.clear();
    game.quills.clear();
    game.mazeGates.clear();
    if (step == TutorialStep.heartsHoles) {
      // A visible, avoidable obstacle, with at least five seconds of approach.
      hole = Hole(
        (game.ballX + (game.ballX < 180 ? 45 : -45)).clamp(70, 290),
        game.ballY - 170,
      );
      game.board.add(hole!);
    }
    if (step == TutorialStep.coins) spawnCoin();
    if (step == TutorialStep.shield || step == TutorialStep.combo)
      spawnPickup();
    if (step == TutorialStep.shieldFeedback) {
      game.survival.shield = math.max(game.survival.shield, 3);
    }
    if (step == TutorialStep.comboFeedback) {
      game.survival.combo = math.max(2, game.survival.combo);
    }
  }

  void spawnCoin() {
    game.coins.clear();
    coin = BrassCoin(game.ballX.clamp(55, 305), game.ballY - 90);
    game.coins.add(coin!);
  }

  void spawnPickup() {
    game.survival.items.clear();
    pickup = InfiniteItem(
      progress.step == TutorialStep.shield
          ? InfiniteItemKind.shield
          : InfiniteItemKind.combo,
      game.ballX.clamp(55, 305),
      game.ballY - 90,
    );
    game.survival.items.add(pickup!);
  }

  void tick(double dt) {
    if (!game.infinite ||
        game.paused ||
        game.waitingForInput ||
        !progress.step.inInfinite)
      return;
    if (game.finished || game.lives <= 0) {
      if (progress.step == TutorialStep.freePlay) advance(TutorialStep.shop);
      return;
    }
    age += dt;
    switch (progress.step) {
      case TutorialStep.controls:
        if ((game.controlHeld ||
                game.pivotTargets.any((p) => p != null) ||
                game.leftInput != 0 ||
                game.rightInput != 0) &&
            ((game.right - game.left).abs() >= 20 ||
                (game.screenY((game.left + game.right) / 2) - initialHeight)
                        .abs() >=
                    18)) {
          advance(TutorialStep.heartsHoles);
        }
      case TutorialStep.heartsHoles:
        if (game.lives < initialLives || game.ballY < hole!.y - 28) {
          advance(TutorialStep.heartsFeedback);
        }
      case TutorialStep.heartsFeedback:
        if (age >= 2) advance(TutorialStep.coins);
      case TutorialStep.coins:
        if (game.coinsCollected > initialCoins) {
          advance(TutorialStep.coinsFeedback);
        } else if (coin!.y > game.ballY + 32 || !game.coins.contains(coin)) {
          spawnCoin();
        }
      case TutorialStep.coinsFeedback:
        if (age >= 2) advance(TutorialStep.shield);
      case TutorialStep.shield:
        if (game.survival.shield > 0) {
          advance(TutorialStep.shieldFeedback);
        } else if (pickup!.y > game.ballY + 32 ||
            !game.survival.items.contains(pickup)) {
          spawnPickup();
        }
      case TutorialStep.shieldFeedback:
        if (age >= 2.5) advance(TutorialStep.metrics);
      case TutorialStep.metrics:
        if (age >= 2.5 && game.score > 0) advance(TutorialStep.combo);
      case TutorialStep.combo:
        if (game.survival.combo > 1) {
          advance(TutorialStep.comboFeedback);
        } else if (pickup!.y > game.ballY + 32 ||
            !game.survival.items.contains(pickup)) {
          spawnPickup();
        }
      case TutorialStep.comboFeedback:
        if (age >= 2.5) advance(TutorialStep.freePlay);
      case TutorialStep.freePlay:
        final before = progress.freePlaySeconds ~/ 5;
        progress.freePlaySeconds = math.min(45, progress.freePlaySeconds + dt);
        if (progress.freePlaySeconds >= 45) {
          advance(TutorialStep.shop);
        } else if (before != progress.freePlaySeconds ~/ 5) {
          onChanged();
        }
      default:
        break;
    }
  }
}
