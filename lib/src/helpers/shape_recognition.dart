import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawn_shape.dart';
import '../models/enums.dart';

/// Recognizes freehand strokes as geometric shapes.
class ShapeRecognizer {
  static ShapeType? recognizeShape(List<Offset> points) {
    if (points.length < 5) return null;

    final simplified = _simplify(points, 5.0);
    final minX = simplified.map((p) => p.dx).reduce(math.min);
    final maxX = simplified.map((p) => p.dx).reduce(math.max);
    final minY = simplified.map((p) => p.dy).reduce(math.min);
    final maxY = simplified.map((p) => p.dy).reduce(math.max);
    final width = maxX - minX;
    final height = maxY - minY;
    final aspect = width / height;

    if (width < 25 || height < 25) return ShapeType.line;

    final corners = _countCorners(simplified);
    final startEndDist = (points.first - points.last).distance;
    final isClosed = startEndDist < 40.0;

    if (corners == 4 || (corners == 5 && isClosed)) {
      if (_hasRightAngles(simplified, 0.6)) return ShapeType.rectangle;
      if (corners == 4 && aspect > 0.8 && aspect < 1.2) return ShapeType.rectangle;
    }

    if (corners == 3) return ShapeType.triangle;

    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final avgRadius = (width + height) / 4;
    if (avgRadius > 10) {
      final variance = simplified
              .map((p) => math.pow((p - center).distance - avgRadius, 2))
              .reduce((a, b) => a + b) /
          simplified.length;
      final normalizedVariance = variance / (avgRadius * avgRadius);
      if (normalizedVariance < 0.2 && corners <= 5) return ShapeType.circle;
    }

    if (corners <= 2) return ShapeType.line;
    if (corners == 4) return ShapeType.rectangle;

    return null;
  }

  static List<ShapeType> getSuggestions(List<Offset> points) {
    final type = recognizeShape(points);
    final suggestions = <ShapeType>[];
    if (type != null) suggestions.add(type);

    final startEndDist = (points.first - points.last).distance;
    final isClosed = startEndDist < 50;

    if (isClosed) {
      if (!suggestions.contains(ShapeType.circle)) suggestions.add(ShapeType.circle);
      if (!suggestions.contains(ShapeType.rectangle)) suggestions.add(ShapeType.rectangle);
    } else {
      if (!suggestions.contains(ShapeType.line)) suggestions.add(ShapeType.line);
    }
    return suggestions;
  }

  static List<Offset> _simplify(List<Offset> points, double tolerance) {
    if (points.length < 3) return points;
    final simplified = <Offset>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      if ((points[i] - simplified.last).distanceSquared > tolerance * tolerance) {
        simplified.add(points[i]);
      }
    }
    simplified.add(points.last);
    return simplified;
  }

  static int _countCorners(List<Offset> points) {
    int corners = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final v1 = points[i - 1] - points[i];
      final v2 = points[i + 1] - points[i];
      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final mag = v1.distance * v2.distance;
      if (mag == 0) continue;
      final angle = math.acos((dot / mag).clamp(-1.0, 1.0));
      if (angle < math.pi * 0.75) corners++;
    }
    return corners;
  }

  static bool _hasRightAngles(List<Offset> points, double toleranceRadians) {
    for (int i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final curr = points[i];
      final next = points[(i + 1) % points.length];
      final v1 = prev - curr;
      final v2 = next - curr;
      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final angle = math.acos((dot / (v1.distance * v2.distance)).clamp(-1.0, 1.0));
      if ((angle - (math.pi / 2)).abs() > toleranceRadians) return false;
    }
    return true;
  }

  static bool isShapeInside(DrawnShape inner, DrawnShape outer) {
    return (inner.start.dx >= outer.start.dx &&
        inner.end.dx <= outer.end.dx &&
        inner.start.dy >= outer.start.dy &&
        inner.end.dy <= outer.end.dy);
  }

  static List<Offset> smoothFreehandPath(List<Offset> points) {
    if (points.length < 3) return points;
    List<Offset> smoothed = [points.first];
    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i - 1], p2 = points[i], p3 = points[i + 1];
      smoothed.add(Offset((p1.dx + p2.dx + p3.dx) / 3, (p1.dy + p2.dy + p3.dy) / 3));
    }
    smoothed.add(points.last);
    return smoothed;
  }
}
