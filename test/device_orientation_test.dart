import 'package:balance_arcade/device_orientation.dart';
import 'package:balance_arcade/board_painter.dart';
import 'package:balance_arcade/pivot_board.dart';
import 'package:balance_arcade/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TouchProbe extends StatefulWidget {
  const _TouchProbe();
  @override
  State<_TouchProbe> createState() => _TouchProbeState();
}

class _TouchProbeState extends State<_TouchProbe> {
  final touches = <int>[];
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var side = 0; side < 2; side++)
        Expanded(
          child: Listener(
            key: ValueKey('side-$side'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => touches.add(side),
            child: const SizedBox.expand(),
          ),
        ),
    ],
  );
}

void main() {
  testWidgets(
    'landscape wide screens have narrower rails with a full-size scenery canvas',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final frame = ValueNotifier(0);
      addTearDown(frame.dispose);
      for (final (isPhone, size, fraction) in [
        (true, const Size(951, 669), .46),
        (true, const Size(669, 951), .74),
        (true, const Size(402, 874), .74),
        (false, const Size(1032, 1376), .74),
        (false, const Size(1376, 1032), .46),
      ]) {
        tester.view.physicalSize = size;
        final game = BalanceGame()..start(gameMode: GameMode.infinite);
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) =>
                PhoneOrientationFrame(isIOSPhone: isPhone, child: child!),
            home: PivotBoard(game: game, frame: frame, fillWidth: 1),
          ),
        );
        final paint = find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is BoardPainter,
        );
        final painter =
            tester.widget<CustomPaint>(paint).painter! as BoardPainter;
        final canvasSize = tester.getSize(paint);
        expect(canvasSize.longestSide, size.longestSide);
        expect(canvasSize.shortestSide, size.shortestSide);
        expect(painter.arenaWidthFraction, fraction);
        if (canvasSize.shortestSide >= 600) {
          final view = BoardViewport.forGame(
            canvasSize,
            game,
            fillWidth: 1,
            arenaWidthFraction: painter.arenaWidthFraction,
          );
          final left = view.project(const Offset(20, 280));
          final right = view.project(const Offset(340, 280));
          expect(
            right.dx - left.dx,
            closeTo(canvasSize.width * fraction, .001),
          );
          expect((left.dx + right.dx) / 2, closeTo(canvasSize.width / 2, .001));
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Duo supports portrait and landscape preserving touches and run state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(669, 951);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              PhoneOrientationFrame(isIOSPhone: true, child: child!),
          home: const Scaffold(body: _TouchProbe()),
        ),
      );
      final state = tester.state<_TouchProbeState>(find.byType(_TouchProbe));
      Size layoutSize() => MediaQuery.sizeOf(state.context);
      expect(layoutSize(), const Size(669, 951));
      expect(tester.getSize(find.byType(_TouchProbe)), const Size(669, 951));
      final left = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('side-0'))),
        pointer: 1,
      );
      final right = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('side-1'))),
        pointer: 2,
      );
      expect(state.touches, [0, 1]);
      await left.up();
      await right.up();

      // Physical landscape, then closing, then opening in portrait again.
      for (final (window, layout) in [
        (const Size(951, 669), const Size(951, 669)),
        (const Size(466, 678), const Size(466, 678)),
        (const Size(669, 951), const Size(669, 951)),
      ]) {
        tester.view.physicalSize = window;
        await tester.pump();
        expect(tester.state(find.byType(_TouchProbe)), same(state));
        expect(layoutSize(), layout);
        expect(tester.getSize(find.byType(_TouchProbe)), layout);
        expect(state.touches, [0, 1]);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Duo preserves native safe insets in portrait', (tester) async {
    const original = MediaQueryData(
      size: Size(669, 951),
      padding: EdgeInsets.fromLTRB(1, 2, 3, 4),
      viewPadding: EdgeInsets.fromLTRB(5, 6, 7, 8),
      viewInsets: EdgeInsets.fromLTRB(9, 10, 11, 12),
      systemGestureInsets: EdgeInsets.fromLTRB(13, 14, 15, 16),
    );
    MediaQueryData? result;
    await tester.pumpWidget(
      MediaQuery(
        data: original,
        child: PhoneOrientationFrame(
          isIOSPhone: true,
          child: Builder(
            builder: (context) {
              result = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(result!.padding, original.padding);
    expect(result!.viewPadding, original.viewPadding);
    expect(result!.viewInsets, original.viewInsets);
    expect(result!.systemGestureInsets, original.systemGestureInsets);
  });

  testWidgets('iPad and compact phone retain their portrait layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (isPhone, size) in [
      (false, const Size(669, 951)),
      (false, const Size(1032, 1376)),
      (true, const Size(402, 874)),
      (true, const Size(466, 678)),
    ]) {
      tester.view.physicalSize = size;
      Size? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) =>
              PhoneOrientationFrame(isIOSPhone: isPhone, child: child!),
          home: Builder(
            builder: (context) {
              result = MediaQuery.sizeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, size);
    }
  });
}
