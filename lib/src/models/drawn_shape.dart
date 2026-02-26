import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'enums.dart';

/// Represents a single drawn shape on the canvas.
///
/// Contains all geometric data, styling, text labels, and transformation state.
/// Use [copy] for a shallow reference-safe clone and [clone] as an alias.
class DrawnShape {
  Offset start;
  Offset end;
  final ShapeType type;

  Map<String, String> texts;
  Map<String, Offset> textPositions;

  List<Offset>? pathPoints;
  Color color;
  double strokeWidth;
  DrawMode mode;
  double fontSize;
  FontStyle fontStyle;
  FontWeight fontWeight;
  double rotation;
  double opacity;

  /// Number of sides for polygon shapes.
  int polygonSides;

  DrawnShape(
    this.start,
    this.end,
    this.type, {
    Map<String, String>? texts,
    Map<String, Offset>? textPositions,
    this.pathPoints,
    required this.color,
    required this.strokeWidth,
    this.mode = DrawMode.stroke,
    this.fontSize = 16.0,
    this.fontStyle = FontStyle.normal,
    this.fontWeight = FontWeight.normal,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.polygonSides = 5,
  })  : texts = texts ?? {},
        textPositions = textPositions ?? {};

  /// Creates a deep copy of this shape.
  DrawnShape copy() {
    return DrawnShape(
      start,
      end,
      type,
      texts: Map<String, String>.from(texts),
      textPositions: Map<String, Offset>.from(textPositions),
      pathPoints: pathPoints != null ? List<Offset>.from(pathPoints!) : null,
      color: color,
      strokeWidth: strokeWidth,
      mode: mode,
      fontSize: fontSize,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      rotation: rotation,
      opacity: opacity,
      polygonSides: polygonSides,
    );
  }

  /// Alias for [copy].
  DrawnShape clone() => copy();

  /// Returns a new shape with the given fields replaced.
  DrawnShape copyWith({
    Offset? start,
    Offset? end,
    ShapeType? type,
    Map<String, String>? texts,
    Map<String, Offset>? textPositions,
    List<Offset>? pathPoints,
    Color? color,
    double? strokeWidth,
    DrawMode? mode,
    double? fontSize,
    FontStyle? fontStyle,
    FontWeight? fontWeight,
    double? rotation,
    double? opacity,
    int? polygonSides,
  }) {
    return DrawnShape(
      start ?? this.start,
      end ?? this.end,
      type ?? this.type,
      texts: texts ?? Map<String, String>.from(this.texts),
      textPositions: textPositions ?? Map<String, Offset>.from(this.textPositions),
      pathPoints: pathPoints ?? (this.pathPoints != null ? List<Offset>.from(this.pathPoints!) : null),
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      mode: mode ?? this.mode,
      fontSize: fontSize ?? this.fontSize,
      fontStyle: fontStyle ?? this.fontStyle,
      fontWeight: fontWeight ?? this.fontWeight,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      polygonSides: polygonSides ?? this.polygonSides,
    );
  }

  /// The normalized bounding box of this shape.
  Rect get bounds {
    if (type == ShapeType.freehand && pathPoints != null && pathPoints!.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final p in pathPoints!) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
    return Rect.fromPoints(start, end);
  }

  /// The center of this shape's bounding box.
  Offset get center => bounds.center;

  /// Hit-test: does [point] lie within this shape?
  bool contains(Offset point) {
    if (type == ShapeType.text) {
      for (final entry in texts.entries) {
        final label = entry.value;
        final pos = textPositions[entry.key] ?? start;
        final textSpan = TextSpan(
          text: label,
          style: TextStyle(fontSize: fontSize, fontStyle: fontStyle, fontWeight: fontWeight),
        );
        final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr)..layout();
        final textBounds = Rect.fromLTWH(pos.dx, pos.dy, textPainter.width, textPainter.height).inflate(10.0);
        if (textBounds.contains(point)) return true;
      }
      return false;
    }

    if (type == ShapeType.freehand && pathPoints != null && pathPoints!.length > 1) {
      for (int i = 0; i < pathPoints!.length - 1; i++) {
        final p1 = pathPoints![i];
        final p2 = pathPoints![i + 1];
        final double tolerance = math.max(strokeWidth + 10.0, 20.0);
        if (_isPointOnLine(p1, p2, point, tolerance)) return true;
      }
      return false;
    }

    final shapeBounds = Rect.fromPoints(start, end).inflate(10);
    final shapeCenter = shapeBounds.center;
    final sinR = math.sin(-rotation);
    final cosR = math.cos(-rotation);
    final translated = point - shapeCenter;
    final rotated = Offset(
      translated.dx * cosR - translated.dy * sinR,
      translated.dx * sinR + translated.dy * cosR,
    );
    return shapeBounds.contains(rotated + shapeCenter);
  }

  static bool _isPointOnLine(Offset p1, Offset p2, Offset test, double tolerance) {
    final line = p2 - p1;
    final toTest = test - p1;
    final lengthSquared = line.distanceSquared;
    if (lengthSquared == 0) return toTest.distance < tolerance;
    final t = (toTest.dx * line.dx + toTest.dy * line.dy) / lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = p1 + line * clampedT;
    return (test - projection).distance < tolerance;
  }

  /// Gets the corner offset for the given resize handle.
  Offset getCornerOffset(ResizeHandle handle) {
    switch (handle) {
      case ResizeHandle.topLeft:
        return Offset(math.min(start.dx, end.dx), math.min(start.dy, end.dy));
      case ResizeHandle.topRight:
        return Offset(math.max(start.dx, end.dx), math.min(start.dy, end.dy));
      case ResizeHandle.bottomLeft:
        return Offset(math.min(start.dx, end.dx), math.max(start.dy, end.dy));
      case ResizeHandle.bottomRight:
        return Offset(math.max(start.dx, end.dx), math.max(start.dy, end.dy));
      default:
        return Offset.zero;
    }
  }

  /// Gets all four corners of the bounding box.
  List<Offset> getCorners() {
    final left = math.min(start.dx, end.dx);
    final right = math.max(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final bottom = math.max(start.dy, end.dy);
    return [Offset(left, top), Offset(right, top), Offset(right, bottom), Offset(left, bottom)];
  }

  /// Serializes this shape to JSON.
  Map<String, dynamic> toJson() {
    return {
      'start': {'dx': start.dx, 'dy': start.dy},
      'end': {'dx': end.dx, 'dy': end.dy},
      'type': type.name,
      'texts': texts,
      'textPositions': textPositions.map((key, pos) => MapEntry(key, {'dx': pos.dx, 'dy': pos.dy})),
      'pathPoints': pathPoints?.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'mode': mode.name,
      'fontSize': fontSize,
      'fontStyle': fontStyle.index,
      'fontWeight': fontWeight.value,
      'rotation': rotation,
      'opacity': opacity,
      'polygonSides': polygonSides,
    };
  }

  /// Deserializes a shape from JSON.
  factory DrawnShape.fromJson(Map<String, dynamic> json) {
    return DrawnShape(
      Offset((json['start']['dx'] as num).toDouble(), (json['start']['dy'] as num).toDouble()),
      Offset((json['end']['dx'] as num).toDouble(), (json['end']['dy'] as num).toDouble()),
      ShapeType.values.firstWhere((e) => e.name == json['type']),
      texts: (json['texts'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
      textPositions: (json['textPositions'] as Map?)?.map((k, v) => MapEntry(k.toString(), Offset((v['dx'] as num).toDouble(), (v['dy'] as num).toDouble()))) ?? {},
      pathPoints: (json['pathPoints'] as List?)?.map((p) => Offset((p['dx'] as num).toDouble(), (p['dy'] as num).toDouble())).toList(),
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      mode: DrawMode.values.firstWhere((e) => e.name == json['mode']),
      fontSize: (json['fontSize'] as num).toDouble(),
      fontStyle: FontStyle.values[json['fontStyle'] as int],
      fontWeight: FontWeight.values.firstWhere((w) => w.value == (json['fontWeight'] as int), orElse: () => FontWeight.normal),
      rotation: (json['rotation'] as num).toDouble(),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      polygonSides: (json['polygonSides'] as int?) ?? 5,
    );
  }

  @override
  String toString() => 'DrawnShape(type: $type, start: $start, end: $end)';
}
