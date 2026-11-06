import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capture_replay_data.dart';
import 'capture_run.dart';
import 'ball_shop.dart';
import 'ball_cosmetics.dart';
import 'platforms.dart';
import 'enemy_sounds.dart';
import 'game.dart';
import 'infinite_coin_chip.dart';
import 'infinite_painter.dart';
import 'infinite_progress.dart';
import 'infinite_boss.dart';
import 'menu_design.dart';
import 'pivot_board.dart';
import 'profile.dart';
import 'premium_menu.dart' show formatCompactScore, scoreFontSize;
import 'responsive_layout.dart';
import 'device_orientation.dart';
import 'level_picker.dart';

/// Separate entrypoint: flutter run -t lib/capture_main.dart -d DEVICE_UUID
/// No analytics, ads, rewards or result banking. Shop choices are saved normally.
Future<void> main() => launchCaptureApp();

Future<void> launchCaptureApp({bool levelCapture = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final isIOSPhone = await initializeDeviceOrientation();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final profile = PlayerProfile();
  await profile.load();
  runApp(
    CaptureApp(
      profile: profile,
      isIOSPhone: isIOSPhone,
      levelCapture: levelCapture,
    ),
  );
}

const captureSaveKey = 'rollrise.appStoreCapture.v1';
const levelCaptureSaveKey = 'rollrise.appStoreLevelCapture.v2';
const _exportChannel = MethodChannel('rollrise/capture-export');

class CaptureApp extends StatelessWidget {
  const CaptureApp({
    super.key,
    required this.profile,
    this.isIOSPhone = false,
    this.levelCapture = false,
  });
  final PlayerProfile profile;
  final bool isIOSPhone;
  final bool levelCapture;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: arcadeMenuTheme(),
    builder: (context, child) => PhoneOrientationFrame(
      isIOSPhone: isIOSPhone,
      child: child ?? const SizedBox(),
    ),
    home: CaptureLobby(profile: profile, levelCapture: levelCapture),
  );
}

class CaptureLobby extends StatefulWidget {
  const CaptureLobby({
    super.key,
    required this.profile,
    this.levelCapture = false,
  });
  final PlayerProfile profile;
  final bool levelCapture;
  @override
  State<CaptureLobby> createState() => _CaptureLobbyState();
}

class _CaptureLobbyState extends State<CaptureLobby> {
  String? saved, bundled, bundledInfo, error;
  bool loading = true;
  bool useShopLook = false;
  int selectedLevel = 1;
  String get saveKey =>
      widget.levelCapture ? levelCaptureSaveKey : captureSaveKey;

  Future<void> chooseLevel() async {
    final number = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: LevelPicker(
              selected: selectedLevel,
              allLevelsUnlocked: true,
              controlMode: ControlMode.twoFinger,
              onSelected: (number) => Navigator.pop(context, number),
            ),
          ),
        ),
      ),
    );
    if (number == null || !mounted) return;
    setState(() => selectedLevel = number);
    await play(null, number);
  }

  Future<void> shop() async {
    final p = widget.profile;
    if (p.wallet < 300000) {
      p.wallet = 300000;
      await p.saveEconomy();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(body: BallShop(profile: p)),
      ),
    );
    if (mounted) setState(() => useShopLook = true);
  }

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final last = await SharedPreferencesAsync().getString(saveKey);
      var baked = bundledCaptureReplay.isEmpty
          ? null
          : utf8.decode(base64Decode(bundledCaptureReplay));
      var take = baked == null ? null : CaptureFile.decode(baked);
      if (widget.levelCapture && take?.setup.level == null) {
        baked = null;
        take = null;
      }
      final seconds = take == null ? 0 : (take.ticks / captureHz).round();
      final info = take == null
          ? null
          : 'Bundled take: ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · ${take.setup.level == null ? 'final score ${take.summary['score']}' : 'Level ${take.setup.level} · ${take.summary['completed']}/10 targets'}';
      if (take != null)
        debugPrint(
          'Bundled capture loaded: ${take.ticks} ticks; ${take.summary}',
        );
      if (mounted)
        setState(() {
          saved = last;
          bundled = baked;
          bundledInfo = info;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> play([String? text, int? level]) async {
    try {
      final p = widget.profile;
      final replay = text == null ? null : CaptureFile.decode(text);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CaptureScreen(
            profile: p,
            setup: CaptureSetup(
              ball: p.selectedBall,
              platform: p.selectedPlatform,
              cabinet: p.cabinet,
              hearts: p.startingHearts,
              shieldSeconds: p.shieldDuration,
              magnetSeconds: p.magnetDuration,
              firstBoss: level == null ? BossKind.venomCrown : null,
              level: level,
            ),
            replay: replay,
            replayBall: useShopLook ? p.selectedBall : null,
            replayPlatform: useShopLook ? p.selectedPlatform : null,
          ),
        ),
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> export(String text) async {
    try {
      await _exportChannel.invokeMethod<bool>('share', text);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not export: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: menuBackground,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.levelCapture ? 'Level capture' : 'App Store capture',
                  style: const TextStyle(
                    color: menuText,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.levelCapture
                      ? 'Choose any Classic level and play with two fingers. After the level ends, export its JSON file to replay on another device. Normal progress is untouched.'
                      : 'A separate Infinite run with the same seed every time. Play with two fingers. Inputs save in the background; each new take replaces the saved take. Normal progress is untouched.',
                  style: const TextStyle(color: menuMuted, height: 1.5),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: shop,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('SHOP · CHANGE BALL'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use shop appearance in replay'),
                  subtitle: Text(
                    '${widget.profile.selectedBall.label} · ${widget.profile.selectedPlatform.label}. Recorded gameplay stays the same.',
                  ),
                  value: useShopLook,
                  onChanged: (value) => setState(() => useShopLook = value),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : widget.levelCapture
                      ? chooseLevel
                      : () => play(),
                  child: Text(
                    widget.levelCapture
                        ? 'CHOOSE LEVEL TO RECORD'
                        : 'RECORD FIXED INFINITE RUN',
                  ),
                ),
                if (saved != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => play(saved),
                    child: const Text('REPLAY SAVED TAKE'),
                  ),
                  OutlinedButton(
                    onPressed: () => export(saved!),
                    child: const Text('EXPORT SAVED JSON FILE'),
                  ),
                ],
                if (bundled != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    bundledInfo!,
                    key: const ValueKey('bundled-take-info'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: menuMuted),
                  ),
                  FilledButton(
                    onPressed: () => play(bundled),
                    child: const Text('PLAY BUNDLED REPLAY'),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'To send a take: pause → Finish & save → Export JSON file → Save to Files. On wide screens, double-tap the top-right corner to pause recording. Replay starts after a 3-second countdown; trim that countdown from the video.',
                  style: TextStyle(color: menuMuted, height: 1.5),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.profile,
    required this.setup,
    this.replay,
    this.replayBall,
    this.replayPlatform,
  });
  final PlayerProfile profile;
  final CaptureSetup setup;
  final CaptureFile? replay;
  final BallCosmetic? replayBall;
  final PlatformStyle? replayPlatform;
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CaptureRecorder? recorder;
  CapturePlayer? player;
  BalanceGame get game => recorder?.game ?? player!.game;
  final frame = ValueNotifier(0);
  final feedback = GameFeedback();
  final sounds = EnemySoundDirector();
  late final Ticker ticker;
  Timer? countdownTimer;
  Duration? previous;
  double accumulator = 0;
  int countdown = 0;
  bool paused = false, done = false, saving = false;
  String? error, saveError;
  Future<void> pendingSave = Future.value();
  int get ticks => recorder?.ticks ?? player!.ticks;

  @override
  void initState() {
    super.initState();
    if (widget.replay == null) {
      recorder = CaptureRecorder(widget.setup);
    } else {
      player = CapturePlayer(
        widget.replay!,
        visualBall: widget.replayBall,
        visualPlatform: widget.replayPlatform,
      );
      countdown = 3;
    }
    WidgetsBinding.instance.addObserver(this);
    feedback.setEnemyEffectsEnabled(widget.profile.sound);
    ticker = createTicker(tick);
    if (player == null) {
      ticker.start();
    } else {
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => countdown--);
        if (countdown == 0) {
          timer.cancel();
          if (!paused) ticker.start();
        }
      });
    }
  }

  Future<void> persist() {
    if (recorder == null || recorder!.ticks == 0) return pendingSave;
    final json = recorder!.snapshot().encode();
    pendingSave = pendingSave.then((_) async {
      try {
        await SharedPreferencesAsync().setString(
          recorder!.setup.level == null ? captureSaveKey : levelCaptureSaveKey,
          json,
        );
        if (mounted && saveError != null) setState(() => saveError = null);
      } catch (e) {
        if (mounted)
          setState(
            () => saveError =
                'Local save failed: $e. Export this take before closing.',
          );
      }
    });
    return pendingSave;
  }

  void tick(Duration now) {
    final delta = previous == null
        ? 1 / captureHz
        : (now - previous!).inMicroseconds / 1000000;
    previous = now;
    if (game.waitingForInput && recorder != null) {
      frame.value++;
      return;
    }
    accumulator += math.min(delta, .1);
    final cues = <EnemyCue>{};
    try {
      while (accumulator >= 1 / captureHz && !done) {
        if (recorder != null) {
          recorder!.step();
        } else {
          player!.step();
        }
        accumulator -= 1 / captureHz;
        cues.addAll(sounds.capture(game));
        if (game.event != null) {
          unawaited(feedback.play(game.event!, widget.profile));
          game.event = null;
        }
        if (recorder != null && ticks % (captureHz * 2) == 0)
          unawaited(persist());
        if (recorder?.stopped == true || player?.complete == true) {
          if (recorder != null) {
            unawaited(finish());
          } else {
            ticker.stop();
            setState(() => done = true);
          }
        }
      }
    } catch (e) {
      ticker.stop();
      setState(() {
        error = '$e';
        done = true;
      });
    }
    for (final cue in cues) {
      unawaited(feedback.playEnemy(cue));
    }
    frame.value++;
  }

  void pause() {
    if (done || paused) return;
    recorder?.clearControls();
    // Pauses are excluded from the input clock; only released controls persist.
    if (recorder != null) game.paused = true;
    ticker.stop();
    previous = null;
    accumulator = 0;
    setState(() => paused = true);
    unawaited(persist());
  }

  void resume() {
    if (recorder != null) game.paused = false;
    previous = null;
    accumulator = 0;
    setState(() => paused = false);
    if (countdown == 0) ticker.start();
  }

  Future<void> finish() async {
    setState(() {
      saving = true;
      done = true;
      paused = false;
    });
    recorder?.stopped = true;
    ticker.stop();
    await persist();
    if (mounted) setState(() => saving = false);
  }

  Future<void> export() async {
    try {
      final json = recorder!.snapshot().encode();
      await persist();
      await _exportChannel.invokeMethod<bool>('share', json);
    } catch (e) {
      if (mounted) setState(() => error = 'Export failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  @override
  void dispose() {
    game.onPivotInput = null;
    countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    feedback.dispose();
    frame.dispose();
    super.dispose();
  }

  Widget hud() => ValueListenableBuilder(
    valueListenable: frame,
    builder: (context, _, _) {
      final wide = usesWideStage(MediaQuery.sizeOf(context));
      final color = wide || !game.infinite
          ? menuText
          : infiniteBoardInk(game, const Offset(110, 60));
      final score = game.infinite
          ? formatCompactScore(game.score)
          : '${game.completed}/10';
      final detail = TextStyle(
        color: color,
        fontSize: wide ? 14 : 11,
        fontWeight: FontWeight.w700,
      );
      final hearts = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < game.heartCapacity; i++)
            Icon(
              i < game.lives
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: i < game.lives ? const Color(0xFFEF6958) : menuMuted,
              size: wide ? 22 : 20,
            ),
        ],
      );
      final scoreColumn = AnimatedOpacity(
        opacity: game.boss != null ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                score,
                key: ValueKey(
                  game.infinite ? 'infinite-score' : 'classic-capture-progress',
                ),
                style: TextStyle(
                  color: color,
                  fontSize: scoreFontSize(wide ? 32 : 30, score),
                  height: wide ? 1.1 : 1.15,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              game.infinite
                  ? '${game.survival.combo}×${game.survival.combo == InfiniteTuning.maxCombo ? ' MAX' : ''}'
                  : 'LEVEL ${game.level} · ${game.elapsed ~/ 60}:${(game.elapsed.toInt() % 60).toString().padLeft(2, '0')}',
              style: detail,
            ),
            if (!game.infinite && game.levelStarCollected)
              Text(
                '★ BONUS STAR',
                style: detail.copyWith(color: const Color(0xFFF0C979)),
              ),
            if (game.infinite)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InfiniteCoinChip(
                    wallet: math.max(300000, widget.profile.wallet),
                    collected: game.coinsCollected,
                    ink: color,
                    sinceCoin: game.lastCoinAge,
                  ),
                ),
              ),
          ],
        ),
      );
      final pauseButton = player == null && !wide
          ? IconButton.filledTonal(
              onPressed: pause,
              tooltip: 'Pause',
              style: IconButton.styleFrom(
                fixedSize: Size.square(wide ? 64 : 44),
                backgroundColor: wide ? menuRaised : color.withAlpha(24),
                foregroundColor: color,
              ),
              icon: Icon(Icons.pause_rounded, size: wide ? 32 : 22),
            )
          : const SizedBox.shrink();
      return SafeArea(
        left: !wide,
        right: !wide,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: wide
                ? math.min(1280, MediaQuery.sizeOf(context).width * .8)
                : double.infinity,
            child: Padding(
              padding: wide
                  ? const EdgeInsets.only(top: 10)
                  : const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) ...[
                    Expanded(
                      child: Align(
                        heightFactor: 1,
                        alignment: Alignment.topLeft,
                        child: FittedBox(fit: BoxFit.scaleDown, child: hearts),
                      ),
                    ),
                    Expanded(child: scoreColumn),
                    Expanded(
                      child: Align(
                        heightFactor: 1,
                        alignment: Alignment.topRight,
                        child: player == null
                            ? GestureDetector(
                                key: const ValueKey('capture-pause-gesture'),
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: pause,
                                child: const SizedBox.square(dimension: 64),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: 72,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: hearts,
                        ),
                      ),
                    ),
                    Expanded(child: scoreColumn),
                    SizedBox(
                      width: 72,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: pauseButton,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget panel() => ColoredBox(
    color: menuBackground.withAlpha(245),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                error != null
                    ? (player == null ? 'Capture error' : 'Replay stopped')
                    : done
                    ? (player != null
                          ? 'Replay complete'
                          : game.infinite
                          ? 'Take saved'
                          : game.won
                          ? 'Level complete'
                          : 'Level ended')
                    : 'Paused',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: menuText,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                game.infinite
                    ? '${(ticks / captureHz).toStringAsFixed(1)} seconds · ${game.score} points'
                    : 'Level ${game.level} · ${game.completed}/10 targets · ${(ticks / captureHz).toStringAsFixed(1)} seconds',
                textAlign: TextAlign.center,
                style: const TextStyle(color: menuMuted),
              ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              if (saveError != null)
                Text(
                  saveError!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              const SizedBox(height: 20),
              if (!done)
                FilledButton(
                  onPressed: resume,
                  child: const Text('RESUME RUN'),
                ),
              if (!done && recorder != null)
                OutlinedButton(
                  onPressed: finish,
                  child: const Text('FINISH & SAVE'),
                ),
              if (done && recorder != null && ticks > 0)
                FilledButton(
                  onPressed: saving ? null : export,
                  child: const Text('EXPORT JSON FILE'),
                ),
              if (done && recorder != null && !game.infinite)
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(context).pushReplacement<void, void>(
                          MaterialPageRoute(
                            builder: (_) => CaptureScreen(
                              profile: widget.profile,
                              setup: widget.setup,
                            ),
                          ),
                        ),
                  child: const Text('RECORD LEVEL AGAIN'),
                ),
              if (done)
                OutlinedButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('BACK TO CAPTURE MENU'),
                ),
              if (!done && player != null)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BACK TO CAPTURE MENU'),
                ),
              if (!done && recorder != null && ticks == 0)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BACK TO CAPTURE MENU'),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (done || recorder?.started != true),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) pause();
    },
    child: Scaffold(
      backgroundColor: menuBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: player != null || paused || done,
            child: PivotBoard(
              game: game,
              frame: frame,
              fillWidth: 1,
              contentTop: widget.replay?.geometry.top,
              bottomPadding: MediaQuery.paddingOf(context).bottom,
              fitHeight: MediaQuery.viewPaddingOf(context).horizontal > 0,
              overlay: const SizedBox.shrink(),
            ),
          ),
          hud(),
          if (recorder != null && !paused && !done)
            ValueListenableBuilder(
              valueListenable: frame,
              builder: (context, _, _) => game.waitingForInput
                  ? const IgnorePointer(
                      child: Center(
                        child: Text(
                          'Move both handles to start',
                          style: TextStyle(color: menuText, fontSize: 18),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          if (countdown > 0 && !paused)
            IgnorePointer(
              child: Center(
                child: Text(
                  '$countdown',
                  style: const TextStyle(
                    color: menuText,
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (paused || done) panel(),
        ],
      ),
    ),
  );
}
