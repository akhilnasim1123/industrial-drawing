import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import '../controllers/drawing_controller.dart';
import '../models/drawn_shape.dart';
import '../models/enums.dart';

/// Custom painter that renders all shapes, grid, selection indicators,
/// measurement lines, and previews on the canvas.
///
/// Uses a [revision] integer for efficient [shouldRepaint] comparison
/// instead of always returning true.
class DrawingPainter extends CustomPainter {
  final List<DrawnShape> shapes;
  final Offset? start;
  final Offset? end;
  final bool isDrawing;
  final ShapeType currentShape;
  final Color color;
  final double strokeWidth;
  final DrawMode mode;
  final Tool currentTool;
  final Offset? measurementStart;
  final Offset? measurementEnd;
  final DrawnShape? selectedShape;
  final bool showGrid;
  final bool isResizing;
  final double canvasScale;
  final Offset canvasOffset;
  final double handleRadius;
  final int revision;
  final Offset? eraserPosition;
  final double eraserRadius;

  DrawingPainter(
    this.shapes,
    this.start,
    this.end,
    this.isDrawing,
    this.currentShape,
    this.color,
    this.strokeWidth,
    this.mode,
    this.currentTool,
    this.measurementStart,
    this.measurementEnd,
    this.selectedShape, {
    this.showGrid = true,
    this.isResizing = false,
    this.canvasScale = 1.0,
    this.canvasOffset = Offset.zero,
    this.handleRadius = 12.0,
    this.revision = 0,
    this.eraserPosition,
    this.eraserRadius = 20.0,
  });

  /// Creates a painter directly from a [DrawingController].
  factory DrawingPainter.fromController(DrawingController c, {bool showGrid = true}) {
    return DrawingPainter(
      c.drawnShapes,
      c.startPoint,
      c.endPoint,
      c.isDrawing,
      c.currentShape,
      c.strokeColor,
      c.strokeWidth,
      c.drawMode,
      c.currentTool,
      c.measurementStart,
      c.measurementEnd,
      c.selectedShape,
      showGrid: showGrid,
      isResizing: c.isResizing,
      canvasScale: c.canvasScale,
      canvasOffset: c.canvasOffset,
      handleRadius: c.handleRadius,
      revision: c.revision,
      eraserPosition: c.eraserPosition,
      eraserRadius: c.config.eraserRadius,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(canvasScale);
    canvas.translate(-center.dx, -center.dy);

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    if (showGrid) _drawGrid(canvas, size);

    // Non-text shapes first, then text on top
    for (final shape in shapes.where((s) => s.type != ShapeType.text)) {
      _drawShape(canvas, shape);
    }
    for (final shape in shapes.where((s) => s.type == ShapeType.text)) {
      _drawShape(canvas, shape);
    }

    // Preview shape while drawing
    if (isDrawing && start != null && end != null && currentTool == Tool.draw && currentShape != ShapeType.freehand) {
      _drawShape(canvas, DrawnShape(start!, end!, currentShape, color: color.withOpacity(0.5), strokeWidth: strokeWidth, mode: mode));
    }

    // Measurement line
    if (currentTool == Tool.measure && measurementStart != null && measurementEnd != null) {
      _drawMeasurementLine(canvas);
    }

    // Selection indicator
    if (selectedShape != null) _drawSelectionIndicator(canvas, selectedShape!);

    // Eraser cursor
    if (currentTool == Tool.eraser && eraserPosition != null) {
      _drawEraserCursor(canvas);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.grey.shade300..strokeWidth = 0.5;
    const double gridSize = 20.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  void _drawShape(Canvas canvas, DrawnShape s) {
    final paint = Paint()
      ..color = s.color.withOpacity(s.opacity)
      ..strokeWidth = s.strokeWidth
      ..style = s.mode == DrawMode.fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shapeCenter = Rect.fromPoints(s.start, s.end).center;
    canvas.save();
    canvas.translate(shapeCenter.dx, shapeCenter.dy);
    canvas.rotate(s.rotation);
    canvas.translate(-shapeCenter.dx, -shapeCenter.dy);

    switch (s.type) {
      case ShapeType.line:
        canvas.drawLine(s.start, s.end, paint);
        break;
      case ShapeType.rectangle:
        canvas.drawRect(Rect.fromPoints(s.start, s.end), paint);
        break;
      case ShapeType.circle:
        final rect = Rect.fromPoints(s.start, s.end);
        canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
        break;
      case ShapeType.triangle:
        canvas.drawPath(Path()..moveTo(s.start.dx, s.end.dy)..lineTo(s.end.dx, s.end.dy)..lineTo((s.start.dx + s.end.dx) / 2, s.start.dy)..close(), paint);
        break;
      case ShapeType.freehand:
        if (s.pathPoints != null && s.pathPoints!.length > 1) {
          final path = Path()..moveTo(s.pathPoints!.first.dx, s.pathPoints!.first.dy);
          for (var i = 1; i < s.pathPoints!.length; i++) {
            path.lineTo(s.pathPoints![i].dx, s.pathPoints![i].dy);
          }
          canvas.drawPath(path, paint..style = PaintingStyle.stroke);
        }
        break;
      case ShapeType.arrow:
        _drawArrow(canvas, s, paint);
        break;
      case ShapeType.star:
        _drawStar(canvas, s, paint);
        break;
      case ShapeType.polygon:
        _drawPolygon(canvas, s, paint);
        break;
      case ShapeType.dimension:
        _drawDimensionLine(canvas, s, paint);
        break;
      case ShapeType.lShape:
        final path = Path()
          ..moveTo(s.start.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy + (s.end.dy - s.start.dy) * 0.3)
          ..lineTo(s.start.dx + (s.end.dx - s.start.dx) * 0.3, s.start.dy + (s.end.dy - s.start.dy) * 0.3)
          ..lineTo(s.start.dx + (s.end.dx - s.start.dx) * 0.3, s.end.dy)
          ..lineTo(s.start.dx, s.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.tShape:
        final w = s.end.dx - s.start.dx;
        final t = w * 0.3;
        final path = Path()
          ..moveTo(s.start.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy + t)
          ..lineTo(s.start.dx + (w + t) / 2, s.start.dy + t)
          ..lineTo(s.start.dx + (w + t) / 2, s.end.dy)
          ..lineTo(s.start.dx + (w - t) / 2, s.end.dy)
          ..lineTo(s.start.dx + (w - t) / 2, s.start.dy + t)
          ..lineTo(s.start.dx, s.start.dy + t)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.uShape:
        final w = s.end.dx - s.start.dx;
        final u = w * 0.25;
        final path = Path()
          ..moveTo(s.start.dx, s.start.dy)
          ..lineTo(s.start.dx + u, s.start.dy)
          ..lineTo(s.start.dx + u, s.end.dy - u)
          ..lineTo(s.end.dx - u, s.end.dy - u)
          ..lineTo(s.end.dx - u, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy)
          ..lineTo(s.end.dx, s.end.dy)
          ..lineTo(s.start.dx, s.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.boxShape:
        final outer = Rect.fromPoints(s.start, s.end);
        final thickness = (s.end.dx - s.start.dx).abs() * 0.2;
        final path = Path()..addRect(outer)..addRect(outer.deflate(thickness))..fillType = PathFillType.evenOdd;
        canvas.drawPath(path, paint);
        break;
      case ShapeType.text:
        s.texts.forEach((key, label) {
          _drawText(canvas, s.textPositions[key] ?? s.start, label, s.color, s.fontSize, s.fontStyle, s.fontWeight);
        });
        break;
    }

    // Attached text labels (non-text shapes)
    if (s.type != ShapeType.text && s.texts.isNotEmpty) {
      s.texts.forEach((key, label) {
        _drawText(canvas, s.textPositions[key] ?? s.start, label, s.color, s.fontSize, s.fontStyle, s.fontWeight);
      });
    }

    canvas.restore();
  }

  void _drawArrow(Canvas canvas, DrawnShape s, Paint paint) {
    canvas.drawLine(s.start, s.end, paint);
    // Arrowhead
    final angle = math.atan2(s.end.dy - s.start.dy, s.end.dx - s.start.dx);
    const headLength = 16.0;
    const headAngle = 0.5;
    final p1 = Offset(s.end.dx - headLength * math.cos(angle - headAngle), s.end.dy - headLength * math.sin(angle - headAngle));
    final p2 = Offset(s.end.dx - headLength * math.cos(angle + headAngle), s.end.dy - headLength * math.sin(angle + headAngle));
    final headPaint = Paint()..color = paint.color..style = PaintingStyle.fill;
    canvas.drawPath(Path()..moveTo(s.end.dx, s.end.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(), headPaint);
  }

  void _drawStar(Canvas canvas, DrawnShape s, Paint paint) {
    final rect = Rect.fromPoints(s.start, s.end);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final outerR = rect.shortestSide / 2;
    final innerR = outerR * 0.4;
    const spikes = 5;
    final path = Path();
    for (int i = 0; i < spikes * 2; i++) {
      final r = (i % 2 == 0) ? outerR : innerR;
      final a = (math.pi / spikes) * i - math.pi / 2;
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawPolygon(Canvas canvas, DrawnShape s, Paint paint) {
    final rect = Rect.fromPoints(s.start, s.end);
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final r = rect.shortestSide / 2;
    final sides = s.polygonSides.clamp(3, 12);
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = (2 * math.pi / sides) * i - math.pi / 2;
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDimensionLine(Canvas canvas, DrawnShape s, Paint paint) {
    // Main line
    canvas.drawLine(s.start, s.end, paint);

    // End ticks
    final angle = math.atan2(s.end.dy - s.start.dy, s.end.dx - s.start.dx);
    final perp = angle + math.pi / 2;
    const tickLen = 8.0;
    final tickDx = tickLen * math.cos(perp);
    final tickDy = tickLen * math.sin(perp);

    canvas.drawLine(Offset(s.start.dx + tickDx, s.start.dy + tickDy), Offset(s.start.dx - tickDx, s.start.dy - tickDy), paint);
    canvas.drawLine(Offset(s.end.dx + tickDx, s.end.dy + tickDy), Offset(s.end.dx - tickDx, s.end.dy - tickDy), paint);

    // Distance label
    final dist = (s.end - s.start).distance;
    final mid = Offset((s.start.dx + s.end.dx) / 2, (s.start.dy + s.end.dy) / 2);
    _drawText(canvas, Offset(mid.dx, mid.dy - 16), "${dist.toStringAsFixed(1)}", paint.color, 11, FontStyle.normal, FontWeight.w500);
  }

  void _drawEraserCursor(Canvas canvas) {
    final cursorPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(eraserPosition!, eraserRadius, cursorPaint);
    canvas.drawCircle(eraserPosition!, eraserRadius, borderPaint);
  }

  void _drawMeasurementLine(Canvas canvas) {
    final p = Paint()..color = Colors.blue..strokeWidth = 2.0;
    canvas.drawLine(measurementStart!, measurementEnd!, p);
    canvas.drawCircle(measurementStart!, 4, p);
    canvas.drawCircle(measurementEnd!, 4, p);
  }

  void _drawText(Canvas canvas, Offset pos, String text, Color color, double fontSize, FontStyle fontStyle, FontWeight fontWeight) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontStyle: fontStyle, fontWeight: fontWeight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawSelectionIndicator(Canvas canvas, DrawnShape s) {
    final strokePaint = Paint()..color = Colors.blue..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final glowPaint = Paint()..color = Colors.blue.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)..style = PaintingStyle.stroke..strokeWidth = 3;

    Rect bounds;
    if (s.type == ShapeType.freehand && s.pathPoints != null && s.pathPoints!.isNotEmpty) {
      bounds = s.bounds;
    } else if (s.type == ShapeType.text) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      s.texts.forEach((key, label) {
        final pos = s.textPositions[key] ?? s.start;
        final tp = TextPainter(text: TextSpan(text: label, style: TextStyle(fontSize: s.fontSize)), textDirection: ui.TextDirection.ltr)..layout();
        minX = math.min(minX, pos.dx); minY = math.min(minY, pos.dy);
        maxX = math.max(maxX, pos.dx + tp.width); maxY = math.max(maxY, pos.dy + tp.height);
      });
      bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    } else {
      bounds = Rect.fromPoints(s.start, s.end);
    }

    final boundsCenter = bounds.center;
    final scaled = bounds.inflate(7);
    final dashed = _createDashedRect(scaled, 5, 4);

    canvas.save();
    canvas.translate(boundsCenter.dx, boundsCenter.dy);
    canvas.rotate(s.rotation);
    canvas.translate(-boundsCenter.dx, -boundsCenter.dy);

    canvas.drawPath(dashed, glowPaint);
    canvas.drawPath(dashed, strokePaint);

    final hPaint = Paint()..color = Colors.blue..style = PaintingStyle.fill;
    for (final corner in [scaled.topLeft, scaled.topRight, scaled.bottomLeft, scaled.bottomRight]) {
      canvas.drawCircle(corner, handleRadius, hPaint);
      if (corner == scaled.bottomRight || corner == scaled.bottomLeft) {
        _drawIconOnCanvas(canvas, corner, Bootstrap.arrows_angle_expand, 10, Colors.white);
      }
    }
    _drawIconOnCanvas(canvas, boundsCenter, Bootstrap.arrows_move, 22, Colors.blue);

    canvas.restore();

    if (s.texts.isNotEmpty && s.type != ShapeType.text) {
      s.texts.forEach((key, _) {
        final pos = s.textPositions[key] ?? s.start;
        canvas.drawLine(boundsCenter, pos, Paint()..color = Colors.blue.withOpacity(0.5)..strokeWidth = 1.5);
        canvas.drawCircle(pos, handleRadius, hPaint);
      });
    }
  }

  void _drawIconOnCanvas(Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  Path _createDashedRect(Rect rect, double dashW, double dashS) {
    final p = Path();
    p.addPath(_addDashedLine(rect.topLeft, rect.topRight, dashW, dashS), Offset.zero);
    p.addPath(_addDashedLine(rect.topRight, rect.bottomRight, dashW, dashS), Offset.zero);
    p.addPath(_addDashedLine(rect.bottomRight, rect.bottomLeft, dashW, dashS), Offset.zero);
    p.addPath(_addDashedLine(rect.bottomLeft, rect.topLeft, dashW, dashS), Offset.zero);
    return p;
  }

  Path _addDashedLine(Offset start, Offset end, double dashW, double dashS) {
    final path = Path();
    final totalLen = (end - start).distance;
    if (totalLen == 0) return path;
    final dir = Offset((end.dx - start.dx) / totalLen, (end.dy - start.dy) / totalLen);
    double d = 0.0;
    while (d < totalLen) {
      final from = Offset(start.dx + dir.dx * d, start.dy + dir.dy * d);
      final toD = math.min(d + dashW, totalLen);
      final to = Offset(start.dx + dir.dx * toD, start.dy + dir.dy * toD);
      path.moveTo(from.dx, from.dy);
      path.lineTo(to.dx, to.dy);
      d += dashW + dashS;
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) => old.revision != revision;
}
