import 'dart:typed_data';
import 'dart:ui' as ui;

/// Spreads world positions while keeping local sprites, text and strokes at
/// their original size. Translated sprite groups retain their local geometry.
class ArenaCanvas implements ui.Canvas {
  ArenaCanvas(this.canvas, this.stretch);
  final ui.Canvas canvas;
  final double stretch;
  void actor(ui.Offset center, void Function(ui.Canvas) paint) {
    canvas.save();
    final p = point(center);
    canvas.translate(p.dx, p.dy);
    paint(canvas);
    canvas.restore();
  }

  bool _local = false;
  final _stack = <bool>[];

  ui.Offset point(ui.Offset p) => _local ? p : ui.Offset(p.dx * stretch, p.dy);
  ui.Rect rect(ui.Rect r) => _local
      ? r
      : ui.Rect.fromLTRB(r.left * stretch, r.top, r.right * stretch, r.bottom);
  ui.Path path(ui.Path p) => _local
      ? p
      : p.transform(
          Float64List.fromList([
            stretch,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        );
  ui.RRect _clipRound(ui.RRect r) => ui.RRect.fromRectAndCorners(
    rect(r.outerRect),
    topLeft: r.tlRadius,
    topRight: r.trRadius,
    bottomLeft: r.blRadius,
    bottomRight: r.brRadius,
  );
  void _at(ui.Offset center, void Function() paint) {
    if (_local) {
      paint();
      return;
    }
    canvas.save();
    canvas.translate(center.dx * (stretch - 1), 0);
    paint();
    canvas.restore();
  }

  @override
  void save() {
    _stack.add(_local);
    canvas.save();
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    _stack.add(_local);
    canvas.saveLayer(bounds == null ? null : rect(bounds), paint);
  }

  @override
  void restore() {
    _local = _stack.removeLast();
    canvas.restore();
  }

  @override
  void translate(double dx, double dy) {
    canvas.translate(_local ? dx : dx * stretch, dy);
    _local = true;
  }

  @override
  void scale(double sx, [double? sy]) => canvas.scale(sx, sy);
  @override
  void rotate(double radians) => canvas.rotate(radians);
  @override
  void skew(double sx, double sy) => canvas.skew(sx, sy);
  @override
  void transform(Float64List matrix4) => canvas.transform(matrix4);
  @override
  Float64List getTransform() => canvas.getTransform();
  @override
  int getSaveCount() => canvas.getSaveCount();
  @override
  void clipRect(
    ui.Rect r, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) => canvas.clipRect(rect(r), clipOp: clipOp, doAntiAlias: doAntiAlias);
  @override
  void clipRRect(ui.RRect r, {bool doAntiAlias = true}) =>
      canvas.clipRRect(_clipRound(r), doAntiAlias: doAntiAlias);
  @override
  void clipPath(ui.Path p, {bool doAntiAlias = true}) =>
      canvas.clipPath(path(p), doAntiAlias: doAntiAlias);
  @override
  ui.Rect getLocalClipBounds() => canvas.getLocalClipBounds();
  @override
  ui.Rect getDestinationClipBounds() => canvas.getDestinationClipBounds();
  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) =>
      canvas.drawColor(color, blendMode);
  @override
  void drawPaint(ui.Paint paint) => canvas.drawPaint(paint);
  @override
  void drawLine(ui.Offset a, ui.Offset b, ui.Paint paint) =>
      canvas.drawLine(point(a), point(b), paint);
  @override
  void drawRect(ui.Rect r, ui.Paint paint) => canvas.drawRect(rect(r), paint);
  @override
  void drawRRect(ui.RRect r, ui.Paint paint) =>
      _at(r.center, () => canvas.drawRRect(r, paint));
  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) =>
      _at(outer.center, () => canvas.drawDRRect(outer, inner, paint));
  @override
  void drawCircle(ui.Offset p, double radius, ui.Paint paint) =>
      _at(p, () => canvas.drawCircle(p, radius, paint));
  @override
  void drawOval(ui.Rect r, ui.Paint paint) =>
      _at(r.center, () => canvas.drawOval(r, paint));
  @override
  void drawArc(
    ui.Rect r,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    ui.Paint paint,
  ) => _at(
    r.center,
    () => canvas.drawArc(r, startAngle, sweepAngle, useCenter, paint),
  );
  @override
  void drawPath(ui.Path p, ui.Paint paint) => canvas.drawPath(path(p), paint);
  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) => _at(
    offset + ui.Offset(paragraph.longestLine / 2, 0),
    () => canvas.drawParagraph(paragraph, offset),
  );
  @override
  void drawPicture(ui.Picture picture) => canvas.drawPicture(picture);
  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) =>
      _at(offset, () => canvas.drawImage(image, offset, paint));
  @override
  void drawImageRect(
    ui.Image image,
    ui.Rect src,
    ui.Rect dst,
    ui.Paint paint,
  ) => _at(dst.center, () => canvas.drawImageRect(image, src, dst, paint));
  @override
  void drawPoints(
    ui.PointMode pointMode,
    List<ui.Offset> points,
    ui.Paint paint,
  ) => canvas.drawPoints(pointMode, points.map(point).toList(), paint);
  @override
  void drawShadow(
    ui.Path p,
    ui.Color color,
    double elevation,
    bool transparentOccluder,
  ) => canvas.drawShadow(path(p), color, elevation, transparentOccluder);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unprojected arena drawing: ${invocation.memberName}',
  );
}
