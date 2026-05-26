import 'package:flutter/material.dart';

/// A simple line segment used to represent alignment guide lines
/// when shapes are dragged near each other.
class LineSegment {
  /// The starting point of the guide line.
  final Offset start;

  /// The ending point of the guide line.
  final Offset end;

  const LineSegment(this.start, this.end);

  @override
  String toString() => 'LineSegment($start -> $end)';
}
