import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'board_painter.dart';
import 'analog_controls.dart';
import 'game.dart';
import 'laser_maze.dart';
import 'main.dart' show PivotBoard;

Future<void> showMazeEditorCommand(
  BuildContext context, {
  ControlMode control = ControlMode.twoFinger,
  double analogSensitivity = 1,
  double twoFingerSensitivity = 1,
}) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (_) => const _CommandPrompt(),
  );
  if (open == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MazeEditorPage(
          control: control,
          analogSensitivity: analogSensitivity,
          twoFingerSensitivity: twoFingerSensitivity,
        ),
      ),
    );
  }
}

class _CommandPrompt extends StatefulWidget {
  const _CommandPrompt();
  @override
  State<_CommandPrompt> createState() => _CommandPromptState();
}

class _CommandPromptState extends State<_CommandPrompt> {
  final command = TextEditingController();
  String? error;
  void submit() {
    if (command.text.trim().toLowerCase() == '/editor') {
      Navigator.pop(context, true);
    } else {
      setState(() => error = 'Unknown command.');
    }
  }

  @override
  void dispose() {
    command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Command'),
    content: TextField(
      key: const ValueKey('command-input'),
      controller: command,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(hintText: 'Enter command', errorText: error),
      onSubmitted: (_) => submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Run')),
    ],
  );
}

enum MazeDrawTool { road, erase, finish, pan }

class MazeEditorPage extends StatefulWidget {
  const MazeEditorPage({
    super.key,
    this.control = ControlMode.twoFinger,
    this.analogSensitivity = 1,
    this.twoFingerSensitivity = 1,
  });
  final ControlMode control;
  final double analogSensitivity, twoFingerSensitivity;
  static const draftKey = 'gilt.editor.maze.draft.v1';
  @override
  State<MazeEditorPage> createState() => _MazeEditorPageState();
}

class _MazeEditorPageState extends State<MazeEditorPage> {
  final history = MazeEditorHistory(CustomMazeDefinition.starter);
  final name = TextEditingController(text: CustomMazeDefinition.starter.name);
  final transform = TransformationController();
  final storage = SharedPreferencesAsync();
  late LaserMazeCorridor drawing = history.value.drawingCorridor();
  MazeDrawTool tool = MazeDrawTool.road;
  double width = 40;
  bool loading = true, fitRequested = true, fitAll = false, error = false;
  String status =
      'Drag roads from the START dot. Pan/zoom explores the tall canvas.';
  MazePoint? anchor, end;
  int? pointer;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final raw = await storage.getString(MazeEditorPage.draftKey);
      if (!mounted) return;
      if (raw != null) {
        history.value = CustomMazeDefinition.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        name.text = history.value.name;
        drawing = history.value.drawingCorridor();
        status = 'Saved draft loaded. Use Pan/zoom to explore.';
      }
    } catch (_) {
      status = 'Draft could not be loaded. The example is ready to edit.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    name.dispose();
    transform.dispose();
    super.dispose();
  }

  void message(String text, {bool bad = false}) {
    setState(() {
      status = text;
      error = bad;
    });
  }

  void change(CustomMazeDefinition value) {
    setState(() {
      history.change(value);
      drawing = value.drawingCorridor();
      status = 'Draft changed. Save draft in the menu to keep it.';
      error = false;
    });
  }

  void rename() {
    final text = name.text.trim().isEmpty ? 'Untitled maze' : name.text.trim();
    if (text != history.value.name) change(history.value.copyWith(name: text));
    name.text = text;
  }

  void restore(bool undo) {
    setState(() {
      final height = history.value.height;
      if (undo) {
        history.undo();
      } else {
        history.redo();
      }
      name.text = history.value.name;
      drawing = history.value.drawingCorridor();
      if (height != history.value.height) fitRequested = true;
      status = undo ? 'Undo applied.' : 'Redo applied.';
      error = false;
    });
  }

  Future<void> save() async {
    rename();
    try {
      await storage.setString(
        MazeEditorPage.draftKey,
        jsonEncode(history.value.toJson()),
      );
      if (mounted)
        message(
          'Draft saved on this device. Export Dart to add it to the game.',
        );
    } catch (_) {
      if (mounted)
        message(
          'Local saving failed. Export and copy your Dart before leaving.',
          bad: true,
        );
    }
  }

  bool validate() {
    rename();
    final result = history.value.analyze();
    message(
      result.valid
          ? 'Valid route. Ready to playtest or export.'
          : result.errors.join('\n'),
      bad: !result.valid,
    );
    return result.valid;
  }

  Future<void> export() async {
    if (!validate()) return;
    final code = history.value.toDart();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Dart level code',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Paste this entry inside customMazeLevels in lib/custom_maze_levels.dart, then rebuild. It becomes the next Laser Maze route. Keep existing entries in order.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      code,
                      key: const ValueKey('editor-code'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('copy-maze-code'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (sheetContext.mounted)
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('Dart code copied.')),
                      );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Dart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> playtest() async {
    if (!validate()) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MazeEditorPlaytest(
          definition: history.value,
          control: widget.control,
          analogSensitivity: widget.analogSensitivity,
          twoFingerSensitivity: widget.twoFingerSensitivity,
        ),
      ),
    );
  }

  MazePoint snap(Offset position) => MazePoint(
    ((position.dx / 10).round() * 10).clamp(40, 320).toDouble(),
    (((position.dy + 560 - history.value.height) / 10).round() * 10)
        .clamp(560 - history.value.height + 60, 480)
        .toDouble(),
  );
  double distance(MazePoint p, MazeRoad r) {
    final dx = r.to.x - r.from.x, dy = r.to.y - r.from.y;
    final t =
        ((p.x - r.from.x) * dx + (p.y - r.from.y) * dy) / (dx * dx + dy * dy);
    return LaserMazeCorridor.pointDistance(
      p,
      MazePoint(r.from.x + dx * t.clamp(0, 1), r.from.y + dy * t.clamp(0, 1)),
    );
  }

  void down(PointerDownEvent event) {
    if (tool == MazeDrawTool.pan || pointer != null) return;
    FocusScope.of(context).unfocus();
    final p = snap(event.localPosition);
    if (tool == MazeDrawTool.erase) {
      final roads = history.value.roads.toList();
      final index = roads.lastIndexWhere(
        (r) => distance(p, r) <= r.halfWidth + 8,
      );
      if (index >= 0) {
        roads.removeAt(index);
        change(history.value.copyWith(roads: roads));
      }
      return;
    }
    if (tool == MazeDrawTool.finish) {
      final points = history.value.roads.expand((r) => [r.from, r.to]).toList()
        ..sort(
          (a, b) => LaserMazeCorridor.pointDistance(
            p,
            a,
          ).compareTo(LaserMazeCorridor.pointDistance(p, b)),
        );
      if (points.isEmpty ||
          LaserMazeCorridor.pointDistance(p, points.first) > 30) {
        message('Tap the top endpoint of a vertical road.', bad: true);
        return;
      }
      change(history.value.copyWith(finish: points.first));
      message('Finish placed. It must be the highest vertical endpoint.');
      return;
    }
    pointer = event.pointer;
    setState(() {
      anchor = p;
      end = p;
    });
  }

  void move(PointerMoveEvent event) {
    if (pointer != event.pointer || anchor == null) return;
    final p = snap(event.localPosition), a = anchor!;
    setState(
      () => end = (p.x - a.x).abs() >= (p.y - a.y).abs()
          ? MazePoint(p.x, a.y)
          : MazePoint(a.x, p.y),
    );
  }

  void up(PointerEvent event, {bool cancel = false}) {
    if (pointer != event.pointer) return;
    final a = anchor, b = end;
    setState(() {
      pointer = null;
      anchor = end = null;
    });
    if (cancel ||
        a == null ||
        b == null ||
        LaserMazeCorridor.pointDistance(a, b) < 10)
      return;
    if (history.value.roads.length >= 300) {
      message('Maximum 300 segments. Erase a road first.', bad: true);
      return;
    }
    change(
      history.value.copyWith(
        roads: [...history.value.roads, MazeRoad(a, b, width / 2)],
      ),
    );
  }

  void resize(int height) {
    final minimum = 560 - height + 60;
    if (history.value.roads.any(
          (r) => r.from.y < minimum || r.to.y < minimum,
        ) ||
        history.value.finish.y < minimum) {
      message(
        'Erase roads above the shorter canvas and move the finish first.',
        bad: true,
      );
      return;
    }
    change(history.value.copyWith(height: height));
    setState(() => fitRequested = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const FittedBox(fit: BoxFit.scaleDown, child: Text('Maze editor')),
      actions: [
        IconButton(
          tooltip: 'Undo',
          onPressed: history.canUndo ? () => restore(true) : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Redo',
          onPressed: history.canRedo ? () => restore(false) : null,
          icon: const Icon(Icons.redo),
        ),
        PopupMenuButton<String>(
          tooltip: 'Editor menu',
          onSelected: (value) {
            if (value == 'save') save();
            if (value == 'clear') change(history.value.copyWith(roads: []));
            if (value == 'check') validate();
            if (value == 'fit' || value == 'start')
              setState(() {
                fitAll = value == 'fit';
                fitRequested = true;
              });
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'save', child: Text('Save draft')),
            PopupMenuItem(value: 'check', child: Text('Validate route')),
            PopupMenuItem(value: 'fit', child: Text('Fit whole map')),
            PopupMenuItem(value: 'start', child: Text('Return to START')),
            PopupMenuItem(
              value: 'clear',
              child: Text('Clear roads (undo available)'),
            ),
          ],
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    key: const ValueKey('editor-name'),
                    controller: name,
                    maxLength: 48,
                    decoration: const InputDecoration(
                      labelText: 'Level name',
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => rename(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Wrap(
                    spacing: 5,
                    children: [
                      for (final entry in [
                        (MazeDrawTool.road, 'Road', Icons.edit),
                        (MazeDrawTool.erase, 'Erase', Icons.backspace_outlined),
                        (MazeDrawTool.finish, 'Finish', Icons.flag),
                        (MazeDrawTool.pan, 'Pan/zoom', Icons.pan_tool_outlined),
                      ])
                        ChoiceChip(
                          label: Text(entry.$2),
                          avatar: Icon(entry.$3, size: 15),
                          selected: tool == entry.$1,
                          onSelected: (_) => setState(() {
                            tool = entry.$1;
                            pointer = null;
                            anchor = end = null;
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      DropdownButton<int>(
                        key: const ValueKey('editor-height'),
                        value: history.value.height,
                        items: [
                          for (final h in CustomMazeDefinition.heights)
                            DropdownMenuItem(
                              value: h,
                              child: Text(
                                '${h ~/ 560} screen${h == 560 ? '' : 's'}',
                              ),
                            ),
                        ],
                        onChanged: (h) {
                          if (h != null) resize(h);
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Width ${width.round()}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Expanded(
                        child: Slider(
                          value: width,
                          min: 22,
                          max: 56,
                          divisions: 17,
                          label: '${width.round()}',
                          onChanged: (v) => setState(() => width = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        if (fitRequested) {
                          fitRequested = false;
                          final height = history.value.height;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final scale = math.min(
                              (bounds.maxWidth - 16) / 360,
                              fitAll ? (bounds.maxHeight - 16) / height : 1.2,
                            );
                            transform.value = Matrix4.identity()
                              ..translateByDouble(
                                (bounds.maxWidth - 360 * scale) / 2,
                                bounds.maxHeight - height * scale - 8,
                                0,
                                1,
                              )
                              ..scaleByDouble(scale, scale, 1, 1);
                          });
                        }
                        return InteractiveViewer(
                          transformationController: transform,
                          constrained: false,
                          minScale: .06,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(120),
                          panEnabled: tool == MazeDrawTool.pan,
                          scaleEnabled: tool == MazeDrawTool.pan,
                          child: Listener(
                            onPointerDown: down,
                            onPointerMove: move,
                            onPointerUp: (e) => up(e),
                            onPointerCancel: (e) => up(e, cancel: true),
                            child: CustomPaint(
                              key: const ValueKey('editor-canvas'),
                              size: Size(360, history.value.height.toDouble()),
                              painter: _EditorPainter(
                                history.value,
                                drawing,
                                anchor,
                                end,
                                width / 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 4),
                  child: Text(
                    status,
                    key: const ValueKey('editor-status'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: error ? Colors.red.shade800 : ink,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: playtest,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Playtest'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: export,
                          icon: const Icon(Icons.code),
                          label: const Text('Export Dart'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );
}

class _EditorPainter extends CustomPainter {
  _EditorPainter(this.definition, this.road, this.a, this.b, this.width);
  final CustomMazeDefinition definition;
  final LaserMazeCorridor road;
  final MazePoint? a, b;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE2DFD0),
    );
    final grid = Path();
    for (var x = 0.0; x <= 360; x += 10) {
      grid.moveTo(x, 0);
      grid.lineTo(x, size.height);
    }
    for (var y = 0.0; y <= size.height; y += 10) {
      grid.moveTo(0, y);
      grid.lineTo(360, y);
    }
    canvas.drawPath(
      grid,
      Paint()
        ..color = ink.withAlpha(22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );
    canvas.save();
    canvas.translate(0, definition.height - 560.0);
    final fill = Path();
    for (final r in road.rects) {
      fill.addRect(Rect.fromLTRB(r.left, r.top, r.right, r.bottom));
    }
    canvas.drawPath(fill, Paint()..color = ink);
    for (final wall in road.walls) {
      canvas.drawLine(
        Offset(wall.a.x, wall.a.y),
        Offset(wall.b.x, wall.b.y),
        Paint()
          ..color = const Color(0xFFF44859)
          ..strokeWidth = 4,
      );
    }
    for (final r in definition.roads) {
      for (final p in [r.from, r.to])
        canvas.drawCircle(
          Offset(p.x, p.y),
          2.5,
          Paint()..color = const Color(0xFF89C4B9),
        );
    }
    if (a != null && b != null) {
      canvas.drawLine(
        Offset(a!.x, a!.y),
        Offset(b!.x, b!.y),
        Paint()
          ..color = const Color(0x887ADCC5)
          ..strokeWidth = width * 2
          ..strokeCap = StrokeCap.square,
      );
    }
    void label(String text, MazePoint p, Color color) {
      canvas.drawCircle(Offset(p.x, p.y), 5, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(p.x - label.width / 2, p.y + 10));
    }

    label('START', CustomMazeDefinition.launch, const Color(0xFFB2E6CC));
    label('FINISH', definition.finish, const Color(0xFFFFCE72));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EditorPainter old) => true;
}

class MazeEditorPlaytest extends StatefulWidget {
  const MazeEditorPlaytest({
    super.key,
    required this.definition,
    this.control = ControlMode.twoFinger,
    this.analogSensitivity = 1,
    this.twoFingerSensitivity = 1,
  });
  final ControlMode control;
  final double analogSensitivity, twoFingerSensitivity;
  final CustomMazeDefinition definition;
  @override
  State<MazeEditorPlaytest> createState() => _MazeEditorPlaytestState();
}

class _MazeEditorPlaytestState extends State<MazeEditorPlaytest>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final game = BalanceGame();
  final frame = ValueNotifier(0);
  late final Ticker ticker;
  Duration? last;
  @override
  void initState() {
    super.initState();
    game.setControlMode(widget.control);
    game.analogSensitivity = widget.analogSensitivity;
    game.twoFingerSensitivity = widget.twoFingerSensitivity;
    game.startCustomMaze(widget.definition);
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker((now) {
      if (last != null)
        game.step(math.min(.05, (now - last!).inMicroseconds / 1000000));
      last = now;
      frame.value++;
    })..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) game.setPaused(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Test: ${widget.definition.name}'),
      actions: [
        IconButton(
          tooltip: 'Pause / resume',
          onPressed: () => game.setPaused(!game.paused),
          icon: const Icon(Icons.pause),
        ),
      ],
    ),
    body: SafeArea(
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          final key = event.logicalKey;
          if (![
            LogicalKeyboardKey.keyW,
            LogicalKeyboardKey.keyS,
            LogicalKeyboardKey.arrowUp,
            LogicalKeyboardKey.arrowDown,
          ].contains(key))
            return KeyEventResult.ignored;
          final held = HardwareKeyboard.instance.logicalKeysPressed;
          game.leftInput =
              (held.contains(LogicalKeyboardKey.keyS) ? 1.0 : 0) -
              (held.contains(LogicalKeyboardKey.keyW) ? 1.0 : 0);
          game.rightInput =
              (held.contains(LogicalKeyboardKey.arrowDown) ? 1.0 : 0) -
              (held.contains(LogicalKeyboardKey.arrowUp) ? 1.0 : 0);
          return KeyEventResult.handled;
        },
        child: ValueListenableBuilder(
          valueListenable: frame,
          builder: (_, __, ___) => Column(
            children: [
              Text(
                game.paused
                    ? 'Paused'
                    : '${game.score}% · ${game.controlMode.label}',
              ),
              Expanded(
                child: PivotBoard(game: game, frame: frame),
              ),
              if (game.analog)
                SizedBox(
                  height: 104,
                  child: AnalogControls(game: game, frame: frame),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  game.finished
                      ? (game.won
                            ? 'Finish reached. Your route works!'
                            : 'Laser contact. Retry or return to edit.')
                      : game.analog
                      ? 'Use the vertical controls. Test scores stay private.'
                      : game.oneFinger
                      ? 'Move the lower handle in both axes. Test scores stay private.'
                      : 'Drag both grips. Test runs do not save scores.',
                  textAlign: TextAlign.center,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      game.startCustomMaze(widget.definition);
                      last = null;
                    },
                    child: const Text('Retry'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to editor'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}
