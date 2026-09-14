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

class MergeStatus extends StatelessWidget {
  const MergeStatus({super.key, required this.run});
  final MergeRun run;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
    child: Semantics(
      label:
          'Snake from highest in the middle to smallest outside: ${run.segments.join(', ')}. '
          'Next gate requires more than ${run.upcomingGateValue}. '
          'Collect equal or smaller numbers with the solid middle ball. Larger numbers are fatal.',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            run.ended ? 'RUN ENDED' : 'GATE > ${run.upcomingGateValue}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: run.head <= run.upcomingGateValue
                  ? const Color(0xFFCD542F)
                  : const Color(0xFF163D3B),
            ),
          ),
          Text(
            'MATCH ${formatMergeNumber(run.tail)}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

void paintNumberOrb(
  Canvas canvas,
  Offset center,
  int value,
  double radius, {
  bool match = false,
  bool danger = false,
  double opacity = 1,
}) {
  if (danger) {
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = const Color(0xFFCF4036)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final warning = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          fontFamily: 'sans-serif',
          color: Color(0xFFCF4036),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    warning.paint(canvas, center + Offset(-warning.width / 2, -radius - 19));
  }
  if (match)
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = const Color(0xFFFFF4C9).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  canvas.drawCircle(
    center + const Offset(0, 2),
    radius,
    Paint()..color = Colors.black.withValues(alpha: .2 * opacity),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()..color = numberColor(value).withValues(alpha: opacity),
  );
  canvas.drawCircle(
    center - Offset(radius * .28, radius * .35),
    radius * .14,
    Paint()..color = Colors.white.withValues(alpha: .27 * opacity),
  );
  final text = TextPainter(
    text: TextSpan(
      text: formatMergeNumber(value),
      style: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: radius * .85,
        fontWeight: FontWeight.w900,
        color: opacity < 1 ? const Color(0xD9163D3B) : Colors.white,
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
    required this.onRetry,
    required this.onHome,
  });
  final MergeRun run;
  final bool newBest;
  final VoidCallback onRetry, onHome;
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
              run.failedGate != null
                  ? 'Gate not cleared.'
                  : 'Number too large.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF2ECDD),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${newBest ? 'NEW BEST' : 'SCORE'} ${run.score}  ·  HIGHEST ${formatMergeNumber(run.highest)}',
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
                onPressed: onRetry,
                child: const Text('PLAY AGAIN'),
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
