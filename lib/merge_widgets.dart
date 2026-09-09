import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'merge.dart';

Color numberColor(int value) {
  const colors = [
    Color(0xFF416E8B),
    Color(0xFF267D70),
    Color(0xFF95732A),
    Color(0xFFB36330),
    Color(0xFFAD485B),
    Color(0xFF925D98),
    Color(0xFF5868B0),
    Color(0xFF387E99),
    Color(0xFF527931),
    Color(0xFFB44339),
    Color(0xFF846328),
  ];
  return colors[(value.bitLength - 2).clamp(0, 100) % colors.length];
}

class MergeTray extends StatelessWidget {
  const MergeTray({
    super.key,
    required this.run,
    required this.clock,
    this.reducedMotion = false,
  });
  final MergeRun run;
  final double clock;
  final bool reducedMotion;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    child: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 14,
          runSpacing: 3,
          children: [
            Text(
              run.stack.length == 6
                  ? 'FULL — MATCH TO SURVIVE'
                  : 'STACK  ${run.stack.length} / 6',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: run.stack.length == 6
                    ? Colors.red.shade800
                    : const Color(0xFF163D3B),
              ),
            ),
            Text(
              'MATCH ${run.top}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: List.generate(6, (i) {
            final occupied = i < run.stack.length,
                top = i == run.stack.length - 1;
            return Expanded(
              child: Semantics(
                label: occupied
                    ? 'Stack slot ${i + 1}: ${run.stack[i]}${top ? ', match this number' : ''}'
                    : 'Empty stack slot ${i + 1}',
                child: Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: occupied
                        ? numberColor(run.stack[i])
                        : const Color(0x16163D3B),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      width: top ? 2 : 1,
                      color: run.stack.length == 6
                          ? Colors.red.withAlpha(
                              reducedMotion
                                  ? 230
                                  : (175 + 70 * math.sin(clock * 7)).round(),
                            )
                          : top
                          ? const Color(0xFFFFDF88)
                          : const Color(0x22163D3B),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      child: Text(
                        occupied ? '${run.stack[i]}' : '·',
                        style: TextStyle(
                          color: occupied
                              ? Colors.white
                              : const Color(0x55163D3B),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

void paintNumberOrb(
  Canvas canvas,
  Offset center,
  int value,
  double radius, {
  bool match = false,
}) {
  if (match)
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = const Color(0xFFFFF4C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  canvas.drawCircle(
    center + const Offset(0, 2),
    radius,
    Paint()..color = const Color(0x33000000),
  );
  canvas.drawCircle(center, radius, Paint()..color = numberColor(value));
  canvas.drawCircle(
    center - Offset(radius * .28, radius * .35),
    radius * .14,
    Paint()..color = const Color(0x44FFFFFF),
  );
  final text = TextPainter(
    text: TextSpan(
      text: '$value',
      style: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: radius * .85,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  canvas.save();
  canvas.translate(center.dx, center.dy);
  final scale = math.min(1.0, radius * 1.7 / text.width);
  canvas.scale(scale);
  text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
  canvas.restore();
}

class MergeResult extends StatelessWidget {
  const MergeResult({
    super.key,
    required this.run,
    required this.newBest,
    required this.onContinue,
    required this.onRetry,
    required this.onHome,
  });
  final MergeRun run;
  final bool newBest;
  final VoidCallback onContinue, onRetry, onHome;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xF0163D3B),
      borderRadius: BorderRadius.circular(20),
    ),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              run.won ? '2048. You made it.' : 'Stack full.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF2ECDD),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${newBest ? 'NEW BEST' : 'SCORE'} ${run.score}  ·  HIGHEST ${run.highest}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFDF88),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFDF88),
                  foregroundColor: const Color(0xFF163D3B),
                ),
                onPressed: run.won ? onContinue : onRetry,
                child: Text(run.won ? 'CONTINUE TO 4096' : 'PLAY AGAIN'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              run.notice,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCAD5CD), fontSize: 11),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (run.won)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'NEW RUN',
                      style: TextStyle(color: Color(0xFFFFDF88)),
                    ),
                  ),
                TextButton(
                  onPressed: onHome,
                  child: const Text(
                    'BACK TO CLUB',
                    style: TextStyle(color: Color(0xFFCAD5CD)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
