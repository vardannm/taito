import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balance_arcade/board_painter.dart';

void main() {
  test(
    'portrait gameplay fills height by exposing more world, with uniform geometry',
    () {
      const size = Size(390, 844);
      final view = BoardViewport(size, fillWidth: 1);
      expect(view.rect, Offset.zero & size);
      expect(view.topExtension, greaterThan(200));
      final origin = view.project(Offset.zero);
      expect(
        (view.project(const Offset(10, 0)) - origin).distance,
        closeTo((view.project(const Offset(0, 10)) - origin).distance, .00001),
      );
      expect(
        view.project(Offset(0, -view.topExtension)).dy,
        closeTo(0, .00001),
      );
    },
  );
  for (final size in [
    const Size(1130, 776),
    const Size(390, 680),
    const Size(800, 1040),
    const Size(320, 410),
  ]) {
    test('board preserves circles and fits completely in $size', () {
      final view = BoardViewport(size);
      final center = view.project(const Offset(180, 280));
      final horizontal = view.project(const Offset(190, 280)) - center;
      final vertical = view.project(const Offset(180, 290)) - center;
      expect(horizontal.distance, closeTo(vertical.distance, .00001));
      expect(view.rect.width / view.rect.height, closeTo(360 / 560, .00001));
      expect(view.rect.left, greaterThanOrEqualTo(-.00001));
      expect(view.rect.top, greaterThanOrEqualTo(-.00001));
      expect(view.rect.right, lessThanOrEqualTo(size.width + .00001));
      expect(view.rect.bottom, lessThanOrEqualTo(size.height + .00001));
      expect(
        view.rect.width == size.width ||
            (view.rect.height - size.height).abs() < .00001,
        isTrue,
      );
    });
  }
}
