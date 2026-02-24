import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:icons_plus/icons_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ShapeType {
  line,
  rectangle,
  triangle,
  text,
  freehand,
  lShape,
  circle,
  tShape,
  uShape,
  boxShape
}

enum DrawMode { stroke, fill }

enum Tool { draw, measure, select, pan }

enum ResizeHandle {
  none,
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

enum InteractionMode { smart, move, resize }

ResizeHandle _activeHandle = ResizeHandle.none;

class DrawnShape {
  Offset start;
  Offset end;
  final ShapeType type;

  // 🔹 Multiple text labels
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
  })  : texts = texts ?? {},
        textPositions = textPositions ?? {};

  DrawnShape copy() {
    return DrawnShape(
      start,
      end,
      type,
      texts: Map<String, String>.from(texts), // 🔹 deep copy of texts
      textPositions:
          Map<String, Offset>.from(textPositions), // 🔹 deep copy of positions
      pathPoints: pathPoints != null ? List<Offset>.from(pathPoints!) : null,
      color: color,
      strokeWidth: strokeWidth,
      mode: mode,
      fontSize: fontSize,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      rotation: rotation,
    );
  }

  bool contains(Offset point) {
    // 🔹 If shape contains multiple text labels
    if (type == ShapeType.text) {
      for (final entry in texts.entries) {
        final label = entry.value;
        final pos = textPositions[entry.key] ?? start; // fallback to start

        final textSpan = TextSpan(
          text: label,
          style: TextStyle(
            fontSize: fontSize,
            fontStyle: fontStyle,
            fontWeight: fontWeight,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final textBounds = Rect.fromLTWH(
          pos.dx,
          pos.dy,
          textPainter.width,
          textPainter.height,
        ).inflate(10.0); // 🔹 adds padding for easier selection

        if (textBounds.contains(point)) {
          return true;
        }
      }
      return false;
    }

    // 🔹 Freehand shapes → check line hit
    if (type == ShapeType.freehand &&
        pathPoints != null &&
        pathPoints!.length > 1) {
      for (int i = 0; i < pathPoints!.length - 1; i++) {
        final p1 = pathPoints![i];
        final p2 = pathPoints![i + 1];
        // Use a larger tolerance for easier selection (touch target)
        final double tolerance = math.max(strokeWidth + 10.0, 20.0);
        if (_isPointOnLine(p1, p2, point, tolerance)) {
          return true;
        }
      }
      return false;
    }

    // 🔹 Default: bounding box with rotation
    final bounds = Rect.fromPoints(start, end).inflate(10);
    final center = bounds.center;

    final sinRotation = math.sin(-rotation);
    final cosRotation = math.cos(-rotation);

    final translatedPoint = point - center;
    final rotatedPoint = Offset(
      translatedPoint.dx * cosRotation - translatedPoint.dy * sinRotation,
      translatedPoint.dx * sinRotation + translatedPoint.dy * cosRotation,
    );

    return bounds.contains(rotatedPoint + center);
  }

  static bool _isPointOnLine(
      Offset p1, Offset p2, Offset test, double tolerance) {
    final line = p2 - p1;
    final toTest = test - p1;
    final lengthSquared = line.distanceSquared;
    if (lengthSquared == 0) return toTest.distance < tolerance;
    final t = (toTest.dx * line.dx + toTest.dy * line.dy) / lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = p1 + line * clampedT;
    return (test - projection).distance < tolerance;
  }

  Map<String, dynamic> toJson() {
    return {
      'start': {'dx': start.dx, 'dy': start.dy},
      'end': {'dx': end.dx, 'dy': end.dy},
      'type': type.toString().split('.').last,

      // 🔹 Serialize multiple texts
      'texts': texts.map((key, value) => MapEntry(key, value)),

      // 🔹 Serialize text positions
      'textPositions': textPositions
          .map((key, pos) => MapEntry(key, {'dx': pos.dx, 'dy': pos.dy})),

      'pathPoints': pathPoints?.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'mode': mode.toString().split('.').last,
      'fontSize': fontSize,
      'fontStyle': fontStyle.index,
      'fontWeight': fontWeight.index,
      'rotation': rotation,
    };
  }

  factory DrawnShape.fromJson(Map<String, dynamic> json) {
    return DrawnShape(
      Offset(json['start']['dx'], json['start']['dy']),
      Offset(json['end']['dx'], json['end']['dy']),
      ShapeType.values.firstWhere((e) => e.toString().endsWith(json['type'])),
      texts: (json['texts'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          {},
      textPositions: (json['textPositions'] as Map?)?.map(
            (key, value) =>
                MapEntry(key.toString(), Offset(value['dx'], value['dy'])),
          ) ??
          {},
      pathPoints: (json['pathPoints'] as List?)
          ?.map((p) => Offset(p['dx'], p['dy']))
          .toList(),
      color: Color(json['color']),
      strokeWidth: json['strokeWidth'],
      mode: DrawMode.values
          .firstWhere((e) => e.toString().endsWith(json['mode'])),
      fontSize: json['fontSize'],
      fontStyle: FontStyle.values[json['fontStyle']],
      fontWeight: FontWeight.values[json['fontWeight']],
      rotation: json['rotation'],
    );
  }

  DrawnShape clone() {
    return DrawnShape(
      start,
      end,
      type,
      texts: Map<String, String>.from(texts), // 🔹 deep copy of all labels
      textPositions:
          Map<String, Offset>.from(textPositions), // 🔹 deep copy of positions
      pathPoints: pathPoints != null ? List<Offset>.from(pathPoints!) : null,
      color: color,
      strokeWidth: strokeWidth,
      mode: mode,
      fontSize: fontSize,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      rotation: rotation,
    );
  }
}

class DrawingApp extends StatefulWidget {
  final String? id;
  final String? type;
  const DrawingApp({super.key, this.id, this.type});
  @override
  State<DrawingApp> createState() => _DrawingAppState();
}

class _DrawingAppState extends State<DrawingApp> {
  List<DrawnShape> drawnShapes = [];
  List<List<DrawnShape>> undoStack = [];
  List<List<DrawnShape>> redoStack = [];
  bool loading = false;
  ShapeType currentShape = ShapeType.freehand;
  Tool currentTool = Tool.draw;
  Color shapeColor = Colors.black;
  double strokeWidth = 2.0;
  DrawMode drawMode = DrawMode.stroke;
  Offset? startPoint;
  Offset? endPoint;
  bool isDrawing = false;
  Offset? measurementStart;
  Offset? measurementEnd;
  DrawnShape? _selectedShape;
  Offset? _selectionStartPoint;
  Offset? _lastLineEndPoint;
  bool _smoothFreehand = false;
  Timer? _straightenTimer;
  String _measurementValue = '';
  final GlobalKey canvasKey = GlobalKey();
  final double _snapThreshold = 5.0;
  bool _hasSnapped = false;
  final double _detachThreshold = 3.0;
  bool _isResizing = false;
  Offset? _resizeStartPoint;
  DrawnShape? _initialResizeShape;
  Offset? _snapStartPosition;
  final double handleRadius = 12.0;
  final double touchPadding = 12.0;
  double _canvasScale = 1.0;
  final double _minScale = 0.5;
  final double _maxScale = 4.0;
  Offset _canvasOffset = Offset.zero;
  String? _selectedTextKey;
  Offset? _textDragStartPoint;

  InteractionMode _interactionMode = InteractionMode.smart;
  bool showGrid = true;
  bool _showSideToolbar = true;

  // Hold-to-Suggest State
  Timer? _holdTimer;
  Offset? _suggestionPosition;
  List<ShapeType>? _suggestedShapes;

  void _duplicateSelectedShape() {
    if (_selectedShape != null) {
      _saveStateForUndo();

      final clone = _selectedShape!.clone();
      final offset = Offset(20, 20);

      // Shift shape
      clone.start += offset;
      clone.end += offset;

      // 🔹 Shift all label positions
      clone.textPositions = clone.textPositions.map(
        (key, pos) => MapEntry(key, pos + offset),
      );

      // Shift freehand path points if any
      if (clone.pathPoints != null) {
        clone.pathPoints = clone.pathPoints!.map((p) => p + offset).toList();
      }

      setState(() {
        drawnShapes.add(clone);
        _selectedShape = clone;
      });
    }
  }

  Offset _snapToGrid(Offset point, double gridSize) {
    return Offset(
      (point.dx / gridSize).round() * gridSize,
      (point.dy / gridSize).round() * gridSize,
    );
  }

  void _saveStateForUndo() {
    undoStack.add(drawnShapes.map((s) => s.clone()).toList());
    redoStack.clear();
  }

  void _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        redoStack.add(drawnShapes.map((s) => s.clone()).toList());
        drawnShapes = undoStack.removeLast();
        _selectedShape = null;
      });
    }
  }

  void _redo() {
    if (redoStack.isNotEmpty) {
      setState(() {
        undoStack.add(drawnShapes.map((s) => s.clone()).toList());
        drawnShapes = redoStack.removeLast();
        _selectedShape = null;
      });
    }
  }

  void _clearAll() {
    _saveStateForUndo();
    setState(() {
      drawnShapes.clear();
      _selectedShape = null;
      _lastLineEndPoint = null;
      _measurementValue = '';
    });
  }

  void _deleteSelectedShape() {
    if (_selectedShape != null) {
      _saveStateForUndo();
      setState(() {
        drawnShapes.remove(_selectedShape);
        _selectedShape = null;
      });
    }
  }

  void _rotateSelectedShape() {
    if (_selectedShape != null) {
      _saveStateForUndo();
      setState(() {
        _selectedShape!.rotation += math.pi / 4;
      });
    }
  }

  List<Offset> _smoothFreehandPath(List<Offset> points) {
    if (points.length < 3) return points;
    List<Offset> smoothedPoints = [];
    smoothedPoints.add(points.first);
    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final p3 = points[i + 1];
      final smoothed =
          Offset((p1.dx + p2.dx + p3.dx) / 3, (p1.dy + p2.dy + p3.dy) / 3);
      smoothedPoints.add(smoothed);
    }
    smoothedPoints.add(points.last);
    return smoothedPoints;
  }

  void _resizeSelectedShape(Offset currentPosition) {
    if (_selectedShape == null ||
        _initialResizeShape == null ||
        _resizeStartPoint == null) return;

    final delta = currentPosition - _resizeStartPoint!;

    setState(() {
      _selectedShape!.start = _initialResizeShape!.start;

      _selectedShape!.end = _initialResizeShape!.end + delta;

      if (_selectedShape!.pathPoints != null) {
        final originalStart = _initialResizeShape!.start;
        final originalEnd = _initialResizeShape!.end;
        final scaleX = (_selectedShape!.end.dx - _selectedShape!.start.dx) /
            (originalEnd.dx - originalStart.dx);
        final scaleY = (_selectedShape!.end.dy - _selectedShape!.start.dy) /
            (originalEnd.dy - originalStart.dy);

        _selectedShape!.pathPoints =
            _initialResizeShape!.pathPoints!.map((point) {
          final relativeX = point.dx - originalStart.dx;
          final relativeY = point.dy - originalStart.dy;
          return Offset(
            _selectedShape!.start.dx + relativeX * scaleX,
            _selectedShape!.start.dy + relativeY * scaleY,
          );
        }).toList();
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;

    if (currentTool == Tool.select) {
      if (_selectedShape != null && _selectedShape!.textPositions.isNotEmpty) {
        for (final entry in _selectedShape!.textPositions.entries) {
          if ((entry.value - pos).distance <= 50) {
            _selectedTextKey = entry.key;
            _textDragStartPoint = pos;
            return;
          }
        }
      }

      // Check for handles first if a shape is already selected
      if (_selectedShape != null && _interactionMode != InteractionMode.move) {
        for (final handle in ResizeHandle.values) {
          if (handle == ResizeHandle.none) continue;
          final corner = _getCornerOffsetForHandle(_selectedShape!, handle);
          if ((corner - pos).distance <= handleRadius + 15) {
            _activeHandle = handle;
            _isResizing = true;
            _resizeStartPoint = pos;
            _initialResizeShape = _selectedShape!.copy();
            setState(() {});
            return;
          }
        }
      }

      final shape = _getShapeAtPoint(pos);
      if (shape != null) {
        _selectedShape = shape;
        _selectionStartPoint = pos;
        _saveStateForUndo();
      } else {
        _selectedShape = null;
      }

      setState(() {});
      return;
    }

    // 🔹 Drawing logic
    if (currentTool == Tool.draw &&
        currentShape == ShapeType.line &&
        _lastLineEndPoint != null) {
      final distance = (pos - _lastLineEndPoint!).distance;
      if (distance < 20.0) {
        startPoint = _lastLineEndPoint;
      } else {
        startPoint = pos;
      }
    } else {
      startPoint = pos;
    }

    // 🔹 Freehand drawing
    if (currentTool == Tool.draw && currentShape == ShapeType.freehand) {
      _saveStateForUndo();

      // Clear suggestions if new stroke starts
      if (_suggestedShapes != null) {
        setState(() {
          _suggestedShapes = null;
          _suggestionPosition = null;
        });
      }

      setState(() {
        startPoint = pos;
        drawnShapes.add(DrawnShape(
          startPoint!,
          startPoint!,
          ShapeType.freehand,
          pathPoints: [startPoint!],
          color: shapeColor,
          strokeWidth: strokeWidth,
          mode: drawMode,
        ));
        isDrawing = true;
        _startHoldTimer(pos); // Start timer
      });
    } else {
      _saveStateForUndo();
      setState(() {
        isDrawing = true;
        if (currentTool == Tool.measure) {
          measurementStart = startPoint;
          measurementEnd = startPoint;
          _measurementValue = '0.00 mm';
        }
      });
    }
  }

  ShapeType? recognizeShape(List<Offset> points) {
    if (points.length < 5) return null;

    final simplified = _simplify(points, 5.0);

    final minX = simplified.map((p) => p.dx).reduce(math.min);
    final maxX = simplified.map((p) => p.dx).reduce(math.max);
    final minY = simplified.map((p) => p.dy).reduce(math.min);
    final maxY = simplified.map((p) => p.dy).reduce(math.max);
    final width = maxX - minX;
    final height = maxY - minY;
    final aspect = width / height;

    if (width < 25 || height < 25) {
      return ShapeType.line;
    }

    final corners = _countCorners(simplified);

    // 🔹 improved logic
    final startEndDist = (points.first - points.last).distance;
    final isClosed =
        startEndDist < 40.0; // Assume intended closed loop if starts/ends close

    if (!isClosed && (width > 50 || height > 50)) {
      // If it's a long open path, likely a line or polyline
      // For now, let's allow it to fall through to line
    }

    if (corners == 4 || (corners == 5 && isClosed)) {
      // Relaxed Rectangle Check
      // If it has roughly 4 corners and is closed or nearly closed
      if (_hasRightAngles(simplified, 0.6)) {
        // Increased tolerance ~ 34 degrees
        return ShapeType.rectangle;
      }
      // Fallback: if very square-ish aspect ratio and 4 corners
      if (corners == 4 && aspect > 0.8 && aspect < 1.2) {
        return ShapeType.rectangle; // Likely a square
      }
    }

    if (corners == 3) {
      return ShapeType.triangle;
    }

    // Check for Circle (low variance from center)
    // Normalized variance: variance / (radius^2)
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final avgRadius = (width + height) / 4;
    if (avgRadius > 10) {
      final variance = simplified
              .map((p) => pow((p - center).distance - avgRadius, 2))
              .reduce((a, b) => a + b) /
          simplified.length;
      final normalizedVariance = variance / (avgRadius * avgRadius);

      if (normalizedVariance < 0.2 && corners <= 5) {
        // < 20% deviation
        return ShapeType.circle;
      }
    }

    if (corners <= 2) {
      return ShapeType.line;
    }

    // Fallback based on corners
    if (corners == 4) return ShapeType.rectangle;

    return null;
  }

  List<Offset> _sortCorners(List<Offset> points) {
    final center = Offset(
      points.map((p) => p.dx).reduce((a, b) => a + b) / points.length,
      points.map((p) => p.dy).reduce((a, b) => a + b) / points.length,
    );

    points.sort((a, b) {
      final angleA = math.atan2(a.dy - center.dy, a.dx - center.dx);
      final angleB = math.atan2(b.dy - center.dy, b.dx - center.dx);
      return angleA.compareTo(angleB);
    });

    return points;
  }

  int _countCorners(List<Offset> points) {
    int corners = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final p3 = points[i + 1];

      final v1 = p1 - p2;
      final v2 = p3 - p2;

      final dotProduct = v1.dx * v2.dx + v1.dy * v2.dy;
      final magnitudeProduct = v1.distance * v2.distance;
      if (magnitudeProduct == 0) continue;

      final angle = math.acos((dotProduct / magnitudeProduct).clamp(-1.0, 1.0));

      if (angle < math.pi * 0.75) {
        corners++;
      }
    }
    return corners;
  }

  bool _hasRightAngles(List<Offset> points, double toleranceRadians) {
    for (int i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final curr = points[i];
      final next = points[(i + 1) % points.length];

      final v1 = prev - curr;
      final v2 = next - curr;

      final dot = v1.dx * v2.dx + v1.dy * v2.dy;
      final angle =
          math.acos((dot / (v1.distance * v2.distance)).clamp(-1.0, 1.0));

      if ((angle - (math.pi / 2)).abs() > toleranceRadians) {
        return false;
      }
    }
    return true;
  }

  bool _isConvex(List<Offset> points) {
    int sign = 0;
    for (int i = 0; i < points.length; i++) {
      final dx1 = points[(i + 2) % points.length].dx -
          points[(i + 1) % points.length].dx;
      final dy1 = points[(i + 2) % points.length].dy -
          points[(i + 1) % points.length].dy;
      final dx2 = points[i].dx - points[(i + 1) % points.length].dx;
      final dy2 = points[i].dy - points[(i + 1) % points.length].dy;

      final zcrossproduct = dx1 * dy2 - dy1 * dx2;
      final currentSign = zcrossproduct.sign.toInt();

      if (sign == 0) {
        sign = currentSign;
      } else if (currentSign != 0 && currentSign != sign) {
        return false;
      }
    }
    return true;
  }

  List<Offset> _simplify(List<Offset> points, double tolerance) {
    if (points.length < 3) return points;
    final simplified = <Offset>[];
    simplified.add(points.first);
    for (int i = 1; i < points.length - 1; i++) {
      final p = points[i];
      final prev = simplified.last;
      if ((p - prev).distanceSquared > tolerance * tolerance) {
        simplified.add(p);
      }
    }
    simplified.add(points.last);
    return simplified;
  }

  bool isShapeInside(DrawnShape inner, DrawnShape outer) {
    final innerLeft = inner.start.dx;
    final innerRight = inner.end.dx;
    final innerTop = inner.start.dy;
    final innerBottom = inner.end.dy;

    final outerLeft = outer.start.dx;
    final outerRight = outer.end.dx;
    final outerTop = outer.start.dy;
    final outerBottom = outer.end.dy;

    return (innerLeft >= outerLeft &&
        innerRight <= outerRight &&
        innerTop >= outerTop &&
        innerBottom <= outerBottom);
  }

  Offset _getCornerOffsetForHandle(DrawnShape shape, ResizeHandle handle) {
    final start = shape.start;
    final end = shape.end;

    switch (handle) {
      case ResizeHandle.topLeft:
        return Offset(
          start.dx < end.dx ? start.dx : end.dx,
          start.dy < end.dy ? start.dy : end.dy,
        );
      case ResizeHandle.topRight:
        return Offset(
          start.dx > end.dx ? start.dx : end.dx,
          start.dy < end.dy ? start.dy : end.dy,
        );
      case ResizeHandle.bottomLeft:
        return Offset(
          start.dx < end.dx ? start.dx : end.dx,
          start.dy > end.dy ? start.dy : end.dy,
        );
      case ResizeHandle.bottomRight:
        return Offset(
          start.dx > end.dx ? start.dx : end.dx,
          start.dy > end.dy ? start.dy : end.dy,
        );
      default:
        return Offset.zero;
    }
  }

  void _startHoldTimer(Offset pos) {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 300), () {
      if (isDrawing &&
          currentTool == Tool.draw &&
          currentShape == ShapeType.freehand &&
          drawnShapes.isNotEmpty) {
        final lastShape = drawnShapes.last;
        if (lastShape.pathPoints != null && lastShape.pathPoints!.length > 5) {
          _analyzeForSuggestions(lastShape.pathPoints!, pos);
        }
      }
    });
  }

  void _analyzeForSuggestions(List<Offset> points, Offset pos) {
    // Basic recognition
    final type = recognizeShape(points);
    final suggestions = <ShapeType>[];

    if (type != null) suggestions.add(type);

    // Fallbacks / Alternatives
    final startEndDist = (points.first - points.last).distance;
    final isClosed = startEndDist < 50;

    if (isClosed) {
      if (!suggestions.contains(ShapeType.circle))
        suggestions.add(ShapeType.circle);
      if (!suggestions.contains(ShapeType.rectangle))
        suggestions.add(ShapeType.rectangle);
    } else {
      if (!suggestions.contains(ShapeType.line))
        suggestions.add(ShapeType.line);
    }

    if (suggestions.isNotEmpty) {
      setState(() {
        _suggestedShapes = suggestions;
        _suggestionPosition = pos;
        HapticFeedback.mediumImpact();
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final pos = details.localPosition;
    if (_selectedTextKey != null &&
        _selectedShape != null &&
        _textDragStartPoint != null) {
      final delta = details.localPosition - _textDragStartPoint!;
      setState(() {
        _selectedShape!.textPositions[_selectedTextKey!] =
            _selectedShape!.textPositions[_selectedTextKey!]! + delta;
        _textDragStartPoint = details.localPosition;
      });
      return;
    }
    // === Resizing logic ===
    if (currentTool == Tool.select && _selectedShape != null && !_isResizing) {
      // Logic already handled in onPanStart, but keep as fallback/continuous check
      if (_interactionMode != InteractionMode.move) {
        for (final handle in ResizeHandle.values) {
          if (handle == ResizeHandle.none) continue;
          final corner = _getCornerOffsetForHandle(_selectedShape!, handle);
          if ((corner - pos).distance <= handleRadius + 15) {
            _activeHandle = handle;
            _isResizing = true;
            _resizeStartPoint = pos;
            _initialResizeShape = _selectedShape!.copy();
            setState(() {});
            return;
          }
        }
      }
    }

    if (_isResizing) {
      _resizeSelectedShape(pos);
      return;
    }

    // === Moving shapes ===
    // === Moving shapes ===
    if (currentTool == Tool.select &&
        _selectedShape != null &&
        _selectionStartPoint != null) {
      // Check Interaction Mode
      if (_interactionMode == InteractionMode.resize && !_isResizing) {
        return; // Don't move if in Resize Only mode
      }

      final delta = pos - _selectionStartPoint!;
      final candidateStart = _selectedShape!.start + delta;
      final candidateEnd = _selectedShape!.end + delta;

      final snapOffset =
          _getSnapPoint(candidateStart, candidateEnd, _selectedShape!);
      Offset offsetToApply = delta;

      if (snapOffset != null) {
        if (_hasSnapped) {
          final detachDistance = (pos - (_snapStartPosition ?? pos)).distance;
          if (detachDistance > _detachThreshold) {
            offsetToApply = delta;
            _hasSnapped = false;
            _snapStartPosition = null;
          } else {
            offsetToApply = snapOffset;
          }
        } else {
          offsetToApply = snapOffset;
          _snapStartPosition = pos;
          _hasSnapped = true;
          // HapticFeedback removed for snapping
        }
      } else {
        _hasSnapped = false;
        _snapStartPosition = null;
      }

      setState(() {
        _selectedShape!.start += offsetToApply;
        _selectedShape!.end += offsetToApply;

        // 🔹 Shift all label positions
        _selectedShape!.textPositions = _selectedShape!.textPositions.map(
          (key, pos) => MapEntry(key, pos + offsetToApply),
        );

        // 🔹 Shift freehand path points
        if (_selectedShape!.type == ShapeType.freehand &&
            _selectedShape!.pathPoints != null) {
          _selectedShape!.pathPoints = _selectedShape!.pathPoints!
              .map((p) => p + offsetToApply)
              .toList();
        }

        _selectionStartPoint = pos;
      });

      return;
    }

    setState(() {
      Offset current = pos;

      if (currentTool == Tool.measure) {
        measurementEnd = current;
        final distance = (measurementEnd! - measurementStart!).distance;
        _measurementValue = "${distance.toStringAsFixed(2)} mm";
      }

      if (currentTool == Tool.draw) {
        if (!isDrawing && currentShape == ShapeType.line) {
          final snapStart = _getClosestSnapPoint(current);
          if (snapStart != null) {
            startPoint = snapStart;
            // HapticFeedback removed
          } else {
            startPoint = current;
          }
          isDrawing = true;
        }

        endPoint = current;
        final snapEnd = _getClosestSnapPoint(endPoint!);
        if (snapEnd != null) {
          endPoint = snapEnd;
          // HapticFeedback removed
        }

        if (currentShape == ShapeType.freehand) {
          if (isDrawing &&
              drawnShapes.isNotEmpty &&
              drawnShapes.last.type == ShapeType.freehand) {
            drawnShapes.last.pathPoints!.add(endPoint!);
          }
          _startHoldTimer(pos); // Restart timer
        }
      }
    });
  }

  Offset? _getSnapPoint(
      Offset movingStart, Offset movingEnd, DrawnShape movingShape) {
    Offset? closestSnap;
    double minDistance = double.infinity;

    final movingLeft = min(movingStart.dx, movingEnd.dx);
    final movingRight = max(movingStart.dx, movingEnd.dx);
    final movingTop = min(movingStart.dy, movingEnd.dy);
    final movingBottom = max(movingStart.dy, movingEnd.dy);

    final movingSnapPoints = [
      Offset(movingLeft, movingTop), // top-left
      Offset(movingRight, movingTop), // top-right
      Offset(movingLeft, movingBottom), // bottom-left
      Offset(movingRight, movingBottom), // bottom-right

      Offset((movingLeft + movingRight) / 2, movingTop), // top-center
      Offset((movingLeft + movingRight) / 2, movingBottom), // bottom-center
      Offset(movingLeft, (movingTop + movingBottom) / 2), // left-center
      Offset(movingRight, (movingTop + movingBottom) / 2), // right-center
    ];

    for (final shape in drawnShapes) {
      if (shape == movingShape) continue;

      final targetLeft = min(shape.start.dx, shape.end.dx);
      final targetRight = max(shape.start.dx, shape.end.dx);
      final targetTop = min(shape.start.dy, shape.end.dy);
      final targetBottom = max(shape.start.dy, shape.end.dy);

      final targetSnapPoints = [
        Offset(targetLeft, targetTop),
        Offset(targetRight, targetTop),
        Offset(targetLeft, targetBottom),
        Offset(targetRight, targetBottom),
        Offset((targetLeft + targetRight) / 2, targetTop),
        Offset((targetLeft + targetRight) / 2, targetBottom),
        Offset(targetLeft, (targetTop + targetBottom) / 2),
        Offset(targetRight, (targetTop + targetBottom) / 2),
      ];

      for (final mPoint in movingSnapPoints) {
        for (final tPoint in targetSnapPoints) {
          final distance = (mPoint - tPoint).distance;
          if (distance < _snapThreshold && distance < minDistance) {
            minDistance = distance;
            final direction = (tPoint - mPoint);
            final strength = (1 - (distance / _snapThreshold)).clamp(0.0, 1.0);
            closestSnap = direction * strength;
          }
        }
      }
    }

    return closestSnap;
  }

  void _onPanEnd(DragEndDetails details) {
    _holdTimer?.cancel();
    // Don't clear suggestions immediately on pan end, allow selection.

    if (_isResizing) {
      _isResizing = false;
      _activeHandle = ResizeHandle.none;
      _resizeStartPoint = null;
      _initialResizeShape = null;
    }

    if (currentTool == Tool.select) {
      _selectionStartPoint = null;
      return;
    }

    if (_straightenTimer != null) {
      _straightenTimer!.cancel();
      _straightenTimer = null;
    }

    setState(() {
      if (isDrawing &&
          currentTool == Tool.draw &&
          currentShape != ShapeType.freehand) {
        final shape = DrawnShape(
          startPoint!,
          endPoint ?? startPoint!,
          currentShape,
          color: shapeColor,
          strokeWidth: strokeWidth,
          mode: drawMode,
        );

        // 🔹 Initialize label positions based on shape type
        switch (currentShape) {
          case ShapeType.rectangle:
            shape.textPositions = {
              "Top":
                  Offset((shape.start.dx + shape.end.dx) / 2, shape.start.dy),
              "Right":
                  Offset(shape.end.dx, (shape.start.dy + shape.end.dy) / 2),
              "Bottom":
                  Offset((shape.start.dx + shape.end.dx) / 2, shape.end.dy),
              "Left":
                  Offset(shape.start.dx, (shape.start.dy + shape.end.dy) / 2),
            };
            break;
          case ShapeType.triangle:
            shape.textPositions = {
              "Top":
                  Offset((shape.start.dx + shape.end.dx) / 2, shape.start.dy),
              "Left": Offset(shape.start.dx, shape.end.dy),
              "Right": Offset(shape.end.dx, shape.end.dy),
            };
            break;
          case ShapeType.circle:
            shape.textPositions = {
              "Center": Offset((shape.start.dx + shape.end.dx) / 2,
                  (shape.start.dy + shape.end.dy) / 2),
            };
            break;
          default:
            shape.textPositions = {
              "Center": Offset((shape.start.dx + shape.end.dx) / 2,
                  (shape.start.dy + shape.end.dy) / 2),
            };
        }

        drawnShapes.add(shape);
        _lastLineEndPoint = currentShape == ShapeType.line ? endPoint : null;
      } else if (isDrawing &&
          currentTool == Tool.draw &&
          currentShape == ShapeType.freehand) {
        if (drawnShapes.isEmpty || drawnShapes.last.pathPoints == null) return;

        final points = drawnShapes.last.pathPoints!;
        if (_smoothFreehand && points.length > 2) {
          drawnShapes.last.pathPoints = _smoothFreehandPath(points);
        }
      }

      isDrawing = false;
      startPoint = null;
      endPoint = null;
      measurementStart = null;
      measurementEnd = null;
      _selectedTextKey = null;
      _textDragStartPoint = null;
    });
  }

  Offset? _getClosestSnapPoint(Offset point, {double threshold = 20.0}) {
    Offset? closest;
    double minDistance = threshold;

    for (final shape in drawnShapes) {
      if (shape == _selectedShape) continue; // Skip selected shape

      final candidates = [
        shape.start,
        shape.end,
        Offset(
          (shape.start.dx + shape.end.dx) / 2,
          (shape.start.dy + shape.end.dy) / 2,
        )
      ];

      for (final candidate in candidates) {
        final distance = (candidate - point).distance;
        if (distance < minDistance) {
          closest = candidate;
          minDistance = distance;
        }
      }
    }

    return closest;
  }

  void _onTapUp(TapDownDetails details) {
    if (currentTool == Tool.draw && currentShape == ShapeType.text) {
      _showTextDialog(null, details.localPosition);
    }
    if (currentTool == Tool.select) {
      _selectedTextKey = null;
      final shape = _getShapeAtPoint(details.localPosition);
      if (shape != null) {
        _selectedShape = shape;
        _selectionStartPoint = details.localPosition;
        _saveStateForUndo();
      } else {
        _selectedShape = null;
        _selectedTextKey = null;
      }
      setState(() {});
      return;
    }
  }

  DrawnShape? _getShapeAtPoint(Offset point) {
    for (var i = drawnShapes.length - 1; i >= 0; i--) {
      if (drawnShapes[i].contains(point)) {
        return drawnShapes[i];
      }
    }
    return null;
  }

  Future<void> _saveCanvas() async {
    setState(() => loading = true);
    try {
      final pngBytes = await _exportAsPNG();
      final List<Map<String, dynamic>> drawingData =
          drawnShapes.map((shape) => shape.toJson()).toList();
      final drawingJson = json.encode(drawingData);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Save PNG
      final pngFile = File('${tempDir.path}/drawing_$timestamp.png');
      await pngFile.writeAsBytes(pngBytes);
      
      // Save JSON
      final jsonFile = File('${tempDir.path}/drawing_$timestamp.json');
      await jsonFile.writeAsString(drawingJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Drawing saved locally at ${pngFile.path}")),
        );
      }
    } catch (e) {
      debugPrint('Error saving canvas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save drawing")),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<Uint8List> _exportAsPNG() async {
    try {
      final boundary =
          canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final size = boundary.size;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      DrawingPainter(
        drawnShapes,
        null,
        null,
        false,
        currentShape,
        shapeColor,
        strokeWidth,
        drawMode,
        currentTool,
        null,
        null,
        null,
        showGrid: false,
      ).paint(canvas, size);
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error exporting PNG: $e');
      throw Exception("Failed to export PNG");
    }
  }

  void _layerUp() {
    if (_selectedShape == null) return;
    _saveStateForUndo();
    setState(() {
      final int currentIndex = drawnShapes.indexOf(_selectedShape!);
      if (currentIndex < drawnShapes.length - 1) {
        drawnShapes.removeAt(currentIndex);
        drawnShapes.insert(currentIndex + 1, _selectedShape!);
      }
    });
  }

  void _layerDown() {
    if (_selectedShape == null) return;

    _saveStateForUndo();
    setState(() {
      final int currentIndex = drawnShapes.indexOf(_selectedShape!);
      if (currentIndex > 0) {
        drawnShapes.removeAt(currentIndex);
        drawnShapes.insert(currentIndex - 1, _selectedShape!);
      }
    });
  }

  void _showTextDialog(DrawnShape? targetShape, Offset position) {
    final textController = TextEditingController();
    double tempFontSize = 18.0;

    // If editing an existing shape
    Map<String, String>? existingTexts;
    Map<String, Offset>? existingPositions;
    String? selectedSide;

    if (targetShape != null) {
      existingTexts = targetShape.texts;
      existingPositions = targetShape.textPositions;

      // For shapes, determine positions
      switch (targetShape.type) {
        case ShapeType.rectangle:
          selectedSide ??= "Top";
          break;
        case ShapeType.triangle:
          selectedSide ??= "Top";
          break;
        case ShapeType.circle:
          selectedSide = "Center";
          break;
        default:
          selectedSide = "Center";
      }

      if (selectedSide != null) {
        textController.text = existingTexts?[selectedSide] ?? "";
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Add / Edit Text",
            style: TextStyle(color: Color(0xff1F63E2)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Enter text"),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setStateSlider) => Row(
                  children: [
                    const Text("Size: "),
                    Expanded(
                      child: Slider(
                        value: tempFontSize,
                        min: 10.0,
                        max: 40.0,
                        divisions: 6,
                        label: tempFontSize.toStringAsFixed(1),
                        onChanged: (value) {
                          setStateSlider(() => tempFontSize = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Icon selector for multi-side text (only if shape exists)
              if (targetShape != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: ([
                    if (targetShape.type == ShapeType.rectangle) ...[
                      "Top",
                      "Right",
                      "Bottom",
                      "Left"
                    ],
                    if (targetShape.type == ShapeType.triangle) ...[
                      "Top",
                      "Left",
                      "Right"
                    ],
                    if (targetShape.type == ShapeType.circle) ...["Center"],
                  ]).map((pos) {
                    IconData icon;
                    switch (pos) {
                      case "Top":
                        icon = Icons.arrow_upward;
                        break;
                      case "Bottom":
                        icon = Icons.arrow_downward;
                        break;
                      case "Left":
                        icon = Icons.arrow_back;
                        break;
                      case "Right":
                        icon = Icons.arrow_forward;
                        break;
                      case "Center":
                        icon = Icons.circle;
                        break;
                      default:
                        icon = Icons.crop_square;
                    }

                    return IconButton(
                      icon: Icon(
                        icon,
                        color: selectedSide == pos
                            ? const Color(0xff1F63E2)
                            : Colors.black54,
                      ),
                      tooltip: pos,
                      onPressed: () {
                        setStateSB(() {
                          if (selectedSide != null && existingTexts != null) {
                            existingTexts[selectedSide!] = textController.text;
                          }
                          selectedSide = pos;
                          textController.text =
                              existingTexts?[selectedSide] ?? "";
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isEmpty) return;

                _saveStateForUndo();
                setState(() {
                  if (targetShape != null) {
                    // Editing existing shape
                    targetShape.texts[selectedSide!] = textController.text;

                    final rect =
                        Rect.fromPoints(targetShape.start, targetShape.end);
                    Offset posOffset;
                    switch (selectedSide) {
                      case "Top":
                        posOffset = Offset(rect.center.dx, rect.top);
                        break;
                      case "Bottom":
                        posOffset = Offset(rect.center.dx, rect.bottom);
                        break;
                      case "Left":
                        posOffset = Offset(rect.left, rect.center.dy);
                        break;
                      case "Right":
                        posOffset = Offset(rect.right, rect.center.dy);
                        break;
                      case "Center":
                      default:
                        posOffset = rect.center;
                        break;
                    }

                    targetShape.textPositions[selectedSide!] = posOffset;
                  } else {
                    // Adding a new standalone text
                    drawnShapes.add(DrawnShape(
                      position,
                      position,
                      ShapeType.text,
                      texts: {"Center": textController.text},
                      textPositions: {"Center": position},
                      color: shapeColor,
                      strokeWidth: strokeWidth,
                      fontSize: tempFontSize,
                    ));
                  }
                });

                Navigator.pop(ctx);
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditShapeTextDialog() {
    if (_selectedShape == null) return;

    String? selectedSide = "Top";
    List<String> positions = [];

    // Determine sides based on shape type
    switch (_selectedShape!.type) {
      case ShapeType.rectangle:
        positions = ["Top", "Right", "Bottom", "Left"];
        break;
      case ShapeType.triangle:
        positions = ["Top", "Left", "Right"];
        break;
      case ShapeType.circle:
        positions = ["Center"];
        selectedSide = "Center";
        break;
      default:
        positions = ["Center"];
        selectedSide = "Center";
    }

    // Set initial text for selected side
    final textController = TextEditingController(
        text: selectedSide != null
            ? _selectedShape!.texts[selectedSide] ?? ""
            : "");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Edit Text Labels",
            style: TextStyle(color: Color(0xff1F63E2)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon-based side selector
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: positions.map((pos) {
                    IconData icon;
                    switch (pos) {
                      case "Top":
                        icon = Icons.arrow_upward;
                        break;
                      case "Bottom":
                        icon = Icons.arrow_downward;
                        break;
                      case "Left":
                        icon = Icons.arrow_back;
                        break;
                      case "Right":
                        icon = Icons.arrow_forward;
                        break;
                      case "Center":
                        icon = Icons.circle;
                        break;
                      default:
                        icon = Icons.crop_square;
                    }
                    return IconButton(
                      icon: Icon(
                        icon,
                        color: selectedSide == pos
                            ? const Color(0xff1F63E2)
                            : Colors.black54,
                      ),
                      style: ButtonStyle(
                        backgroundColor: MaterialStatePropertyAll(
                          selectedSide == pos
                              ? const Color(0x6E3D9FF0)
                              : Colors.white,
                        ),
                        shape: MaterialStatePropertyAll(
                          RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1,
                              color: Color(0x6E3D9FF0),
                            ),
                            borderRadius:
                                BorderRadius.circular(20), // adjust as needed
                          ),
                        ),
                      ),
                      tooltip: pos,
                      onPressed: () {
                        setStateDialog(() {
                          // Save current side text before switching
                          if (selectedSide != null) {
                            _selectedShape!.texts[selectedSide!] =
                                textController.text;
                          }

                          selectedSide = pos;
                          textController.text =
                              _selectedShape!.texts[selectedSide!] ?? "";
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Divider(),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Enter text",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _saveStateForUndo();
                setState(() {
                  if (selectedSide != null) {
                    _selectedShape!.texts[selectedSide!] = textController.text;

                    final rect = Rect.fromPoints(
                        _selectedShape!.start, _selectedShape!.end);
                    Offset posOffset;
                    final padding = 20.0;
                    switch (selectedSide) {
                      case "Top":
                        posOffset =
                            Offset(rect.center.dx, rect.top - padding - 5);
                        break;
                      case "Bottom":
                        posOffset =
                            Offset(rect.center.dx, rect.bottom + padding - 15);
                        break;
                      case "Left":
                        if (_selectedShape!.type == ShapeType.triangle) {
                          posOffset =
                              Offset(rect.left - padding + 15, rect.center.dy);
                        } else {
                          posOffset =
                              Offset(rect.left - padding - 20, rect.center.dy);
                        }
                        break;
                      case "Right":
                        if (_selectedShape!.type == ShapeType.triangle) {
                          posOffset =
                              Offset(rect.right + padding - 45, rect.center.dy);
                        } else {
                          posOffset =
                              Offset(rect.right + padding - 15, rect.center.dy);
                        }
                        break;
                      case "Center":
                      default:
                        posOffset = rect.center;
                        break;
                    }
                    _selectedShape!.textPositions[selectedSide!] = posOffset;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveOrShareDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: true, // Tap outside to dismiss
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app,
                size: 50,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 15),
              const Text(
                "Choose Action",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Do you want to save or share your drawing?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _saveCanvas();
                      },
                      child: Text(
                        "Save",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff1F63E2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _shareCanvas();
                      },
                      child: Text(
                        "Share",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
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

  Future<void> _shareCanvas() async {
    try {
      final pngBytes = await _exportAsPNG();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file =
          await File('${tempDir.path}/drawing_$timestamp.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Check out the drawing!",
      );
    } catch (e) {
      debugPrint("Error sharing canvas: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to share drawing")),
      );
    }
  }

  Future<bool?> _confirmSave(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.save_alt,
                size: 50,
                color: Color(0xff1F63E2),
              ),
              const SizedBox(height: 15),
              const Text(
                "Confirm Save",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Do you want to save the canvas?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff1F63E2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        "Save",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
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

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Confirm Clear"),
        content: const Text(
            "Are you sure you want to clear everything? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Clear All"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Drawing?'),
            content: const Text('Any unsaved changes will be lost. Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Exit')),
            ],
          ),
        );
        if (shouldPop ?? false) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
          RepaintBoundary(
            key: canvasKey,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: (details) {
                if (currentTool == Tool.pan) {
                  setState(() {
                    _canvasOffset += details.delta;
                  });
                } else {
                  if (_isResizing) {
                    _resizeSelectedShape(details.localPosition);
                  } else {
                    _onPanUpdate(details);
                  }
                }
              },
              onLongPressStart: (details) {
                // Auto-select shape on long press
                final shape = _getShapeAtPoint(details.localPosition);
                if (shape != null) {
                  setState(() {
                    currentTool = Tool.select;
                    _selectedShape = shape;
                    // Prepare for immediate modification if needed
                    _isResizing = false;
                    _selectionStartPoint = details.localPosition;
                  });
                  // HapticFeedback removed
                } else {
                  // If no shape, just switch to select mode
                  setState(() {
                    currentTool = Tool.select;
                    _selectedShape = null;
                  });
                  // HapticFeedback removed
                }

                // Keep existing resize logic check if already selected (less relevant now with auto-select, but good for safety)
                if (_selectedShape != null &&
                    _selectedShape!.contains(details.localPosition)) {
                  // _isResizing logic is better handled in onPanStart/Update for handles,
                  // but for moving we set selection start above.
                }
              },
              onLongPress: null, // Deprecated/Unused in favor of Start details
              onPanEnd: _onPanEnd,
              onTapDown: _onTapUp,
              child: CustomPaint(
                size: Size.fromWidth(3000),
                painter: DrawingPainter(
                  drawnShapes,
                  startPoint,
                  endPoint,
                  isDrawing,
                  currentShape,
                  shapeColor,
                  strokeWidth,
                  drawMode,
                  currentTool,
                  measurementStart,
                  measurementEnd,
                  _selectedShape,
                  isResizing: _isResizing,
                  canvasScale: _canvasScale,
                  canvasOffset: _canvasOffset,
                  showGrid: showGrid,
                  handleRadius: handleRadius,
                ),
              ),
            ),
          ),

          // Modern UI Layers
          SafeArea(
            child: Column(
              children: [
                _buildHeader(), // Top Bar
                Expanded(
                  child: Stack(
                    children: [
                      // Suggestion Overlay
                      if (_suggestedShapes != null &&
                          _suggestionPosition != null)
                        Positioned(
                          left: (_suggestionPosition!.dx - 60).clamp(
                              0, MediaQuery.of(context).size.width - 150),
                          top: (_suggestionPosition!.dy - 80).clamp(
                              0, MediaQuery.of(context).size.height - 200),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4))
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ..._suggestedShapes!.map((type) {
                                  return GestureDetector(
                                    onTap: () {
                                      if (drawnShapes.isEmpty) return;
                                      final lastShape = drawnShapes.last;
                                      final newShape = DrawnShape(
                                        lastShape.start,
                                        lastShape.end,
                                        type,
                                        color: lastShape.color,
                                        strokeWidth: lastShape.strokeWidth,
                                        mode: lastShape.mode,
                                      );

                                      // Calculate bounds
                                      if (lastShape.pathPoints != null) {
                                        var minX = double.infinity,
                                            minY = double.infinity;
                                        var maxX = double.negativeInfinity,
                                            maxY = double.negativeInfinity;
                                        for (final p in lastShape.pathPoints!) {
                                          minX = math.min(minX, p.dx);
                                          minY = math.min(minY, p.dy);
                                          maxX = math.max(maxX, p.dx);
                                          maxY = math.max(maxY, p.dy);
                                        }
                                        newShape.start = Offset(minX, minY);
                                        newShape.end = Offset(maxX, maxY);
                                      }

                                      setState(() {
                                        drawnShapes.removeLast();
                                        drawnShapes.add(newShape);
                                        _suggestedShapes = null;
                                        _suggestionPosition = null;
                                        isDrawing = false;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0, vertical: 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getIconForShape(type),
                                              color: Colors.blue, size: 24),
                                          Text(_getLabelForShape(type),
                                              style:
                                                  const TextStyle(fontSize: 10))
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.grey.shade300,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (drawnShapes.isNotEmpty &&
                                          drawnShapes.last.type ==
                                              ShapeType.freehand) {
                                        drawnShapes.removeLast();
                                      }
                                      _suggestedShapes = null;
                                      _suggestionPosition = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 24),
                                        const Text("Discard",
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Contextual Panel (Properties)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _buildPropertyPanel(),
                      ),

                      // Measurement Display
                      if (_measurementValue.isNotEmpty &&
                          currentTool == Tool.measure)
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _measurementValue,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),

                      // Canvas Controls
                      Positioned(
                        bottom: 100,
                        right: 10,
                        child: _buildCanvasControls(),
                      ),
                    ],
                  ),
                ),
                _buildBottomToolbar(), // Bottom Floating Dock
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              color: Colors.black,
            ),
          Text(
            'Industrial Drawing',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _undo,
                  tooltip: "Undo"),
              IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: _redo,
                  tooltip: "Redo"),
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: "Save",
                onPressed: () async {
                  if (drawnShapes.isNotEmpty) {
                    final confirmed = await _confirmSave(context);
                    if (confirmed == true) {
                      _showSaveOrShareDialog(context);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Canvas is empty!")),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "Clear All",
                color: Colors.red,
                onPressed: () async {
                  final confirmed = await _confirmClear(context);
                  if (confirmed == true) {
                    _clearAll();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasControls() {
    return Column(
      children: [
        _canvasControlBtn(
          icon: Icons.grid_on,
          isActive: showGrid,
          onTap: () => setState(() => showGrid = !showGrid),
          tooltip: "Toggle Grid",
        ),
        const SizedBox(height: 8),
        _canvasControlBtn(
          icon: Icons.zoom_in,
          onTap: () => setState(() =>
              _canvasScale = (_canvasScale + 0.1).clamp(_minScale, _maxScale)),
          tooltip: "Zoom In",
        ),
        const SizedBox(height: 8),
        _canvasControlBtn(
          icon: Icons.zoom_out,
          onTap: () => setState(() =>
              _canvasScale = (_canvasScale - 0.1).clamp(_minScale, _maxScale)),
          tooltip: "Zoom Out",
        ),
        const SizedBox(height: 8),
         _canvasControlBtn(
           icon: Icons.restart_alt,
           onTap: () => setState(() {
             _canvasScale = 1.0;
             _canvasOffset = Offset.zero;
           }),
           tooltip: "Reset View",
         ),
         const SizedBox(height: 8),
         _canvasControlBtn(
           icon: _showSideToolbar ? Icons.settings : Icons.settings_outlined,
           isActive: _showSideToolbar,
           onTap: () => setState(() => _showSideToolbar = !_showSideToolbar),
           tooltip: "Toggle Properties Panel",
         ),
       ],
     );
   }

  Widget _canvasControlBtn(
      {required IconData icon,
      required VoidCallback onTap,
      bool isActive = false,
      String? tooltip}) {
    return Tooltip(
      message: tooltip ?? "",
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.withOpacity(0.1) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon,
              color: isActive ? Colors.blue : Colors.black87, size: 24),
        ),
      ),
    );
  }

  IconData _getIconForShape(ShapeType type) {
    switch (type) {
      case ShapeType.rectangle:
        return Icons.crop_square;
      case ShapeType.circle:
        return Icons.circle_outlined;
      case ShapeType.triangle:
        return Icons.change_history;
      case ShapeType.line:
        return Icons.remove;
      default:
        return Icons.help_outline;
    }
  }

  String _getLabelForShape(ShapeType type) {
    switch (type) {
      case ShapeType.rectangle:
        return "Rect";
      case ShapeType.circle:
        return "Circle";
      case ShapeType.triangle:
        return "Tri";
      case ShapeType.line:
        return "Line";
      default:
        return "";
    }
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _toolbarSection(
                title: "TOOLS",
                children: [
                  _toolButton(Tool.select, Icons.touch_app, "Select"),
                  _toolButton(Tool.pan, Icons.pan_tool, "Pan"),
                  _toolButton(Tool.measure, Icons.straighten, "Measure"),
                ],
              ),
              Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 12)),
              _toolbarSection(
                title: "SHAPES",
                children: [
                  _shapeButton(ShapeType.freehand, Icons.draw, "Freehand"),
                  _shapeButton(ShapeType.line, Icons.remove, "Line"),
                  _shapeButton(
                      ShapeType.rectangle, Icons.crop_square, "Rectangle"),
                  _shapeButton(
                      ShapeType.circle, Icons.circle_outlined, "Circle"),
                  _shapeButton(
                      ShapeType.triangle, Icons.change_history, "Triangle"),
                  _shapeButton(ShapeType.text, Icons.text_fields, "Text"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarSection(
      {required String title, required List<Widget> children}) {
    return Row(
      children: children,
    );
  }

   Widget _buildPropertyPanel() {
     if (!_showSideToolbar) return const SizedBox.shrink();

     if (currentTool == Tool.draw) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: shapeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.circle_outlined,
                            color: drawMode == DrawMode.stroke
                                ? Colors.blue
                                : Colors.grey),
                        onPressed: () =>
                            setState(() => drawMode = DrawMode.stroke),
                        tooltip: "Stroke",
                        iconSize: 20,
                      ),
                      IconButton(
                        icon: Icon(Icons.circle,
                            color: drawMode == DrawMode.fill
                                ? Colors.blue
                                : Colors.grey),
                        onPressed: () =>
                            setState(() => drawMode = DrawMode.fill),
                        tooltip: "Fill",
                        iconSize: 20,
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 100,
              child: Column(
                children: [
                  Text("Stroke: ${strokeWidth.toInt()}",
                      style: const TextStyle(fontSize: 10)),
                  Slider(
                    value: strokeWidth,
                    min: 1.0,
                    max: 20.0,
                    onChanged: (val) => setState(() => strokeWidth = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedShape != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Post-Drawing Properties (Color, Stroke Width, Fill/Stroke)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _pickSelectedShapeColor,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _selectedShape!.color,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _selectedShape!.mode == DrawMode.fill
                          ? Icons.circle
                          : Icons.circle_outlined,
                      color: Colors.blue,
                      size: 24,
                    ),
                    onPressed: () {
                      _saveStateForUndo();
                      setState(() {
                        _selectedShape!.mode =
                            _selectedShape!.mode == DrawMode.fill
                                ? DrawMode.stroke
                                : DrawMode.fill;
                      });
                    },
                    tooltip: "Toggle Fill/Stroke",
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 120,
                child: Column(
                  children: [
                    Text("Stroke: ${_selectedShape!.strokeWidth.toInt()}",
                        style: const TextStyle(fontSize: 10)),
                    Slider(
                      value: _selectedShape!.strokeWidth,
                      min: 1.0,
                      max: 20.0,
                      onChanged: (val) {
                        setState(() {
                          _selectedShape!.strokeWidth = val;
                        });
                      },
                      onChangeEnd: (val) {
                        _saveStateForUndo();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Mode Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeButton(
                        InteractionMode.smart, Icons.auto_awesome, "Smart"),
                    _modeButton(InteractionMode.move, Icons.open_with, "Move"),
                    _modeButton(
                        InteractionMode.resize, Icons.aspect_ratio, "Resize"),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              _actionButton(Icons.copy, _duplicateSelectedShape, "Duplicate"),
              const SizedBox(height: 8),
              _actionButton(Icons.flip_to_front, _layerUp, "Bring Forward"),
              const SizedBox(height: 8),
              _actionButton(Icons.flip_to_back, _layerDown, "Send Backward"),
              const SizedBox(height: 8),
              _actionButton(Icons.edit, _showEditShapeTextDialog, "Edit Text"),
              const SizedBox(height: 8),
              _actionButton(
                  Icons.rotate_right, _rotateSelectedShape, "Rotate 45°"),
              const SizedBox(height: 8),
              Container(height: 1, width: 24, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              _actionButton(Icons.delete_outline, _deleteSelectedShape, "Delete",
                  color: Colors.red),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _actionButton(IconData icon, VoidCallback onTap, String tooltip,
      {Color color = Colors.black87}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _modeButton(InteractionMode mode, IconData icon, String tooltip) {
    final isSelected = _interactionMode == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _interactionMode = mode),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black12, blurRadius: 2)]
                : null,
          ),
          child: Icon(icon,
              size: 20, color: isSelected ? Colors.blue : Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _toolButton(Tool tool, IconData icon, String label) {
    final isSelected = currentTool == tool;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() {
          currentTool = tool;
          _selectedShape = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff1F63E2).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xff1F63E2).withOpacity(0.3))
                : null,
          ),
          child: Icon(icon,
              color:
                  isSelected ? const Color(0xff1F63E2) : Colors.grey.shade700,
              size: 22),
        ),
      ),
    );
  }

  Widget _shapeButton(ShapeType type, IconData icon, String label) {
    final isSelected = currentTool == Tool.draw && currentShape == type;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => setState(() {
          currentTool = Tool.draw;
          currentShape = type;
          _selectedShape = null;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xff1F63E2).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xff1F63E2).withOpacity(0.3))
                : null,
          ),
          child: Icon(icon,
              color:
                  isSelected ? const Color(0xff1F63E2) : Colors.grey.shade700,
              size: 22),
        ),
      ),
    );
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pick a color"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: shapeColor,
            onColorChanged: (c) => setState(() {
              shapeColor = c;
              if (_selectedShape != null) {
                _selectedShape!.color = shapeColor;
                _selectedShape!.mode = DrawMode.fill;
              }
              ;
            }),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Done")),
        ],
      ),
    );
  }
  void _pickSelectedShapeColor() {
    if (_selectedShape == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pick a color"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedShape!.color,
            onColorChanged: (c) => setState(() {
              _selectedShape!.color = c;
            }),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                _saveStateForUndo();
                Navigator.pop(ctx);
              },
              child: const Text("Done")),
        ],
      ),
    );
  }
}

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
  final bool isResizing; // <--- Add this field here
  final double canvasScale;
  final Offset canvasOffset;
  final double handleRadius;

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
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.translate(canvasOffset.dx, canvasOffset.dy);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(canvasScale);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    if (showGrid) {
      _drawGrid(canvas, size);
    }

    for (final shape in shapes.where((s) => s.type != ShapeType.text)) {
      _drawShape(canvas, shape);
    }

    for (final shape in shapes.where((s) => s.type == ShapeType.text)) {
      _drawShape(canvas, shape);
    }

    if (isDrawing &&
        start != null &&
        end != null &&
        currentTool == Tool.draw &&
        currentShape != ShapeType.freehand) {
      final previewShape = DrawnShape(
        start!,
        end!,
        currentShape,
        color: color.withOpacity(0.5),
        strokeWidth: strokeWidth,
        mode: mode,
      );
      _drawShape(canvas, previewShape);
    }

    if (currentTool == Tool.measure &&
        measurementStart != null &&
        measurementEnd != null) {
      _drawMeasurementLine(canvas);
    }

    if (selectedShape != null) {
      _drawSelectionIndicator(canvas, selectedShape!);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;
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
      ..color = s.color
      ..strokeWidth = s.strokeWidth
      ..style =
          s.mode == DrawMode.fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Rect.fromPoints(s.start, s.end).center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(s.rotation);
    canvas.translate(-center.dx, -center.dy);

    switch (s.type) {
      case ShapeType.line:
        canvas.drawLine(s.start, s.end, paint);
        break;
      case ShapeType.rectangle:
        canvas.drawRect(Rect.fromPoints(s.start, s.end), paint);
        break;
      case ShapeType.circle:
        final rect = Rect.fromPoints(s.start, s.end);
        final radius = rect.shortestSide / 2;
        canvas.drawCircle(rect.center, radius, paint);
        break;
      case ShapeType.triangle:
        final path = Path()
          ..moveTo(s.start.dx, s.end.dy)
          ..lineTo(s.end.dx, s.end.dy)
          ..lineTo((s.start.dx + s.end.dx) / 2, s.start.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.freehand:
        if (s.pathPoints != null && s.pathPoints!.length > 1) {
          final path = Path()
            ..moveTo(s.pathPoints!.first.dx, s.pathPoints!.first.dy);
          for (var i = 1; i < s.pathPoints!.length; i++) {
            path.lineTo(s.pathPoints![i].dx, s.pathPoints![i].dy);
          }
          canvas.drawPath(path, paint..style = PaintingStyle.stroke);
        }
        break;
      case ShapeType.lShape:
        final path = Path()
          ..moveTo(s.start.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy)
          ..lineTo(s.end.dx, s.start.dy + (s.end.dy - s.start.dy) * 0.3)
          ..lineTo(s.start.dx + (s.end.dx - s.start.dx) * 0.3,
              s.start.dy + (s.end.dy - s.start.dy) * 0.3)
          ..lineTo(s.start.dx + (s.end.dx - s.start.dx) * 0.3, s.end.dy)
          ..lineTo(s.start.dx, s.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.tShape:
        final w = s.end.dx - s.start.dx;
        // final h = s.end.dy - s.start.dy;
        final tThickness = w * 0.3; // 30% thickness

        final path = Path()
          ..moveTo(s.start.dx, s.start.dy) // Top-Left
          ..lineTo(s.end.dx, s.start.dy) // Top-Right
          ..lineTo(s.end.dx, s.start.dy + tThickness) // Top-Right Bottom Inner
          ..lineTo(s.start.dx + (w + tThickness) / 2,
              s.start.dy + tThickness) // Center Right
          ..lineTo(s.start.dx + (w + tThickness) / 2, s.end.dy) // Bottom Right
          ..lineTo(s.start.dx + (w - tThickness) / 2, s.end.dy) // Bottom Left
          ..lineTo(s.start.dx + (w - tThickness) / 2,
              s.start.dy + tThickness) // Center Left
          ..lineTo(s.start.dx, s.start.dy + tThickness) // Top-Left Bottom Inner
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.uShape:
        final w = s.end.dx - s.start.dx;
        // final h = s.end.dy - s.start.dy;
        final uThickness = w * 0.25;

        final path = Path()
          ..moveTo(s.start.dx, s.start.dy) // Top-Left
          ..lineTo(s.start.dx + uThickness, s.start.dy) // Top-Left Inner
          ..lineTo(s.start.dx + uThickness,
              s.end.dy - uThickness) // Bottom-Left Inner
          ..lineTo(s.end.dx - uThickness,
              s.end.dy - uThickness) // Bottom-Right Inner
          ..lineTo(s.end.dx - uThickness, s.start.dy) // Top-Right Inner
          ..lineTo(s.end.dx, s.start.dy) // Top-Right
          ..lineTo(s.end.dx, s.end.dy) // Bottom-Right
          ..lineTo(s.start.dx, s.end.dy) // Bottom-Left
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.boxShape:
        final rectOuter = Rect.fromPoints(s.start, s.end);
        final thickness = (s.end.dx - s.start.dx).abs() * 0.2;
        final rectInner = rectOuter.deflate(thickness);

        final path = Path()
          ..addRect(rectOuter)
          ..addRect(rectInner)
          ..fillType = PathFillType.evenOdd;

        canvas.drawPath(path, paint);
        break;
      case ShapeType.text:
        s.texts.forEach((key, label) {
          final pos = s.textPositions[key] ?? s.start;
          _drawText(canvas, pos, label, s.color, s.fontSize, s.fontStyle,
              s.fontWeight);
        });
        break;
    }

    // Draw text labels for non-text shapes
    if (s.type != ShapeType.text && s.texts.isNotEmpty) {
      s.texts.forEach((key, label) {
        final pos = s.textPositions[key] ?? s.start;
        _drawText(
            canvas, pos, label, s.color, s.fontSize, s.fontStyle, s.fontWeight);
      });
    }

    canvas.restore();
  }

  void _drawMeasurementLine(Canvas canvas) {
    final measurementPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0;
    canvas.drawLine(measurementStart!, measurementEnd!, measurementPaint);

    // Draw circles at the ends for clarity
    canvas.drawCircle(measurementStart!, 4, measurementPaint);
    canvas.drawCircle(measurementEnd!, 4, measurementPaint);
  }

  void _drawText(Canvas canvas, Offset position, String text, Color color,
      double fontSize, FontStyle fontStyle, FontWeight fontWeight) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontStyle: fontStyle,
        fontWeight: fontWeight,
      ),
    );
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, position);
  }

  void _drawSelectionIndicator(Canvas canvas, DrawnShape s) {
    final strokePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    Rect bounds;

    if (s.type == ShapeType.freehand && s.pathPoints != null) {
      final minDx = s.pathPoints!.map((p) => p.dx).reduce(math.min);
      final minDy = s.pathPoints!.map((p) => p.dy).reduce(math.min);
      final maxDx = s.pathPoints!.map((p) => p.dx).reduce(math.max);
      final maxDy = s.pathPoints!.map((p) => p.dy).reduce(math.max);
      bounds = Rect.fromPoints(Offset(minDx, minDy), Offset(maxDx, maxDy));
    } else if (s.type == ShapeType.text) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

      s.texts.forEach((key, label) {
        final pos = s.textPositions[key] ?? s.start;
        final textSpan =
            TextSpan(text: label, style: TextStyle(fontSize: s.fontSize));
        final textPainter =
            TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr)
              ..layout();

        minX = math.min(minX, pos.dx);
        minY = math.min(minY, pos.dy);
        maxX = math.max(maxX, pos.dx + textPainter.width);
        maxY = math.max(maxY, pos.dy + textPainter.height);
      });

      bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    } else {
      bounds = Rect.fromPoints(s.start, s.end);
    }

    final center = bounds.center;
    final scaledBounds = bounds.inflate(7);
    final dashedPath = _createDashedRect(scaledBounds, 5, 4);

    // Rotate around center
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(s.rotation);
    canvas.translate(-center.dx, -center.dy);

    // Draw selection rectangle
    canvas.drawPath(dashedPath, glowPaint);
    canvas.drawPath(dashedPath, strokePaint);

    // Corner handles
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final corners = [
      scaledBounds.topLeft,
      scaledBounds.topRight,
      scaledBounds.bottomLeft,
      scaledBounds.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, handleRadius, handlePaint);

      if (corner == scaledBounds.bottomRight ||
          corner == scaledBounds.bottomLeft) {
        _drawIconOnCanvas(
            canvas, corner, Bootstrap.arrows_angle_expand, 10, Colors.white);
      }
    }
    _drawMoveIcon(canvas, center, Bootstrap.arrows_move, 22, Colors.blue);

    canvas.restore();

    if (s.texts.isNotEmpty && s.type != ShapeType.text) {
      s.texts.forEach((key, label) {
        final pos = s.textPositions[key] ?? s.start;
        final connectorPaint = Paint()
          ..color = Colors.blue.withOpacity(0.5)
          ..strokeWidth = 1.5;
        canvas.drawLine(center, pos, connectorPaint);
        canvas.drawCircle(pos, handleRadius, handlePaint);
      });
    }
  }

  void _drawIconOnCanvas(
      Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
        canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawMoveIcon(
      Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Paint the icon centered
    textPainter.paint(
        canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  Path _createDashedRect(Rect rect, double dashWidth, double dashSpace) {
    final path = Path();
    path.addPath(
        _addDashedLine(rect.topLeft, rect.topRight, dashWidth, dashSpace),
        Offset.zero);
    path.addPath(
        _addDashedLine(rect.topRight, rect.bottomRight, dashWidth, dashSpace),
        Offset.zero);
    path.addPath(
        _addDashedLine(rect.bottomRight, rect.bottomLeft, dashWidth, dashSpace),
        Offset.zero);
    path.addPath(
        _addDashedLine(rect.bottomLeft, rect.topLeft, dashWidth, dashSpace),
        Offset.zero);
    return path;
  }

  Path _addDashedLine(
      Offset start, Offset end, double dashWidth, double dashSpace) {
    final path = Path();
    final totalLength = (end - start).distance;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final direction = Offset(dx / totalLength, dy / totalLength);

    double distance = 0.0;

    while (distance < totalLength) {
      final from = Offset(start.dx + direction.dx * distance,
          start.dy + direction.dy * distance);
      final toDistance = math.min(distance + dashWidth, totalLength);
      final to = Offset(start.dx + direction.dx * toDistance,
          start.dy + direction.dy * toDistance);
      path.moveTo(from.dx, from.dy);
      path.lineTo(to.dx, to.dy);
      distance += dashWidth + dashSpace;
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension OffsetExtension on Offset {
  Offset normalize() {
    final length = distance;
    if (length == 0) return this; // Avoid division by zero
    return this / length;
  }
}

extension DrawnShapeContainment on DrawnShape {
  bool contains(Offset point) {
    switch (type) {
      case ShapeType.rectangle:
        final left = math.min(start.dx, end.dx);
        final right = math.max(start.dx, end.dx);
        final top = math.min(start.dy, end.dy);
        final bottom = math.max(start.dy, end.dy);
        return point.dx >= left &&
            point.dx <= right &&
            point.dy >= top &&
            point.dy <= bottom;

      // case ShapeType.circle:
      //   final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      //   final radius = (end - start).distance / 2;
      //   return (point - center).distance <= radius;

      case ShapeType.line:
        const tolerance = 5.0; // pixels
        final distance = _distanceToLineSegment(start, end, point);
        return distance <= tolerance;

      case ShapeType.freehand:
        if (pathPoints == null) return false;
        for (final p in pathPoints!) {
          if ((p - point).distance <= 5.0) return true;
        }
        return false;

      default:
        return false;
    }
  }

  double _distanceToLineSegment(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final ap = p - a;
    final abLengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;

    if (abLengthSquared == 0.0) return (p - a).distance;

    final t =
        ((ap.dx * ab.dx + ap.dy * ab.dy) / abLengthSquared).clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);

    return (p - projection).distance;
  }
}

extension DrawnShapeCorners on DrawnShape {
  List<Offset> getCorners() {
    final left = math.min(start.dx, end.dx);
    final right = math.max(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final bottom = math.max(start.dy, end.dy);
    return [
      Offset(left, top), // topLeft
      Offset(right, top), // topRight
      Offset(right, bottom), // bottomRight
      Offset(left, bottom), // bottomLeft
    ];
  }
}
