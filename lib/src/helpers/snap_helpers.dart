import 'dart:math';
import 'package:flutter/material.dart';
import '../models/drawn_shape.dart';

/// Snap logic for aligning shapes to each other and grids.
class SnapHelper {
  static Offset snapToGrid(Offset point, double gridSize) {
    return Offset(
      (point.dx / gridSize).round() * gridSize,
      (point.dy / gridSize).round() * gridSize,
    );
  }

  static Offset? getSnapPoint(
    Offset movingStart,
    Offset movingEnd,
    DrawnShape movingShape,
    List<DrawnShape> allShapes,
    double snapThreshold,
  ) {
    Offset? closestSnap;
    double minDistance = double.infinity;

    final movingLeft = min(movingStart.dx, movingEnd.dx);
    final movingRight = max(movingStart.dx, movingEnd.dx);
    final movingTop = min(movingStart.dy, movingEnd.dy);
    final movingBottom = max(movingStart.dy, movingEnd.dy);

    final movingSnapPoints = [
      Offset(movingLeft, movingTop),
      Offset(movingRight, movingTop),
      Offset(movingLeft, movingBottom),
      Offset(movingRight, movingBottom),
      Offset((movingLeft + movingRight) / 2, movingTop),
      Offset((movingLeft + movingRight) / 2, movingBottom),
      Offset(movingLeft, (movingTop + movingBottom) / 2),
      Offset(movingRight, (movingTop + movingBottom) / 2),
    ];

    for (final shape in allShapes) {
      if (shape == movingShape) continue;
      final tl = min(shape.start.dx, shape.end.dx);
      final tr = max(shape.start.dx, shape.end.dx);
      final tt = min(shape.start.dy, shape.end.dy);
      final tb = max(shape.start.dy, shape.end.dy);

      final targetSnapPoints = [
        Offset(tl, tt), Offset(tr, tt), Offset(tl, tb), Offset(tr, tb),
        Offset((tl + tr) / 2, tt), Offset((tl + tr) / 2, tb),
        Offset(tl, (tt + tb) / 2), Offset(tr, (tt + tb) / 2),
      ];

      for (final mPoint in movingSnapPoints) {
        for (final tPoint in targetSnapPoints) {
          final distance = (mPoint - tPoint).distance;
          if (distance < snapThreshold && distance < minDistance) {
            minDistance = distance;
            final direction = tPoint - mPoint;
            final strength = (1 - (distance / snapThreshold)).clamp(0.0, 1.0);
            closestSnap = direction * strength;
          }
        }
      }
    }
    return closestSnap;
  }

  static Offset? getClosestSnapPoint(
    Offset point,
    List<DrawnShape> shapes,
    DrawnShape? excludeShape, {
    double threshold = 20.0,
  }) {
    Offset? closest;
    double minDist = threshold;

    for (final shape in shapes) {
      if (shape == excludeShape) continue;
      final candidates = [
        shape.start,
        shape.end,
        Offset((shape.start.dx + shape.end.dx) / 2, (shape.start.dy + shape.end.dy) / 2),
      ];
      for (final c in candidates) {
        final d = (c - point).distance;
        if (d < minDist) {
          closest = c;
          minDist = d;
        }
      }
    }
    return closest;
  }
}
