import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/drawn_shape.dart';
import '../models/enums.dart';
import '../painters/drawing_painter.dart';
import '../helpers/snap_helpers.dart';
import '../helpers/shape_recognition.dart';

/// Configuration for the drawing engine.
///
/// Allows customization of limits, thresholds, and visual settings.
class DrawingConfig {
  /// Maximum undo/redo stack depth.
  final int maxUndoSteps;

  /// Snap threshold in logical pixels.
  final double snapThreshold;

  /// Snap detach threshold.
  final double detachThreshold;

  /// Handle radius for selection handles.
  final double handleRadius;

  /// Minimum canvas scale.
  final double minScale;

  /// Maximum canvas scale.
  final double maxScale;

  /// Grid cell size.
  final double gridSize;

  /// Duration before shape recognition triggers.
  final Duration holdDuration;

  /// Whether to enable shape smoothing.
  final bool enableSmoothing;

  /// Eraser radius.
  final double eraserRadius;

  const DrawingConfig({
    this.maxUndoSteps = 50,
    this.snapThreshold = 5.0,
    this.detachThreshold = 3.0,
    this.handleRadius = 12.0,
    this.minScale = 0.3,
    this.maxScale = 5.0,
    this.gridSize = 20.0,
    this.holdDuration = const Duration(milliseconds: 300),
    this.enableSmoothing = false,
    this.eraserRadius = 20.0,
  });
}

/// The core controller for the drawing engine.
///
/// Manages all drawing state, gesture handling, undo/redo, and shape manipulation.
/// Uses [ChangeNotifier] to efficiently notify listeners of state changes.
///
/// ## Usage
/// ```dart
/// final controller = DrawingController();
/// // ... use with DrawingCanvas widget
/// controller.dispose();
/// ```
class DrawingController extends ChangeNotifier {
  /// Engine configuration.
  final DrawingConfig config;

  DrawingController({this.config = const DrawingConfig()});

  // ── Shape State (encapsulated) ──
  final List<DrawnShape> _shapes = [];
  final List<List<DrawnShape>> _undoStack = [];
  final List<List<DrawnShape>> _redoStack = [];

  /// Read-only view of the current shapes.
  List<DrawnShape> get shapes => List.unmodifiable(_shapes);

  /// Mutable shapes list — use for direct manipulation (e.g., adding shapes).
  /// Prefer [addShape], [removeShape] for tracked operations.
  List<DrawnShape> get drawnShapes => _shapes;

  // ── Tool State ──
  ShapeType _currentShape = ShapeType.freehand;
  Tool _currentTool = Tool.draw;
  Color _strokeColor = Colors.black;
  double _strokeWidth = 2.0;
  DrawMode _drawMode = DrawMode.stroke;
  InteractionMode _interactionMode = InteractionMode.smart;

  ShapeType get currentShape => _currentShape;
  set currentShape(ShapeType value) { _currentShape = value; notifyListeners(); }

  Tool get currentTool => _currentTool;
  set currentTool(Tool value) { _currentTool = value; notifyListeners(); }

  Color get strokeColor => _strokeColor;
  set strokeColor(Color value) { _strokeColor = value; notifyListeners(); }

  double get strokeWidth => _strokeWidth;
  set strokeWidth(double value) { _strokeWidth = value; notifyListeners(); }

  DrawMode get drawMode => _drawMode;
  set drawMode(DrawMode value) { _drawMode = value; notifyListeners(); }

  InteractionMode get interactionMode => _interactionMode;
  set interactionMode(InteractionMode value) { _interactionMode = value; notifyListeners(); }

  // ── Drawing State ──
  bool _isDrawing = false;
  Offset? _startPoint;
  Offset? _endPoint;

  bool get isDrawing => _isDrawing;
  Offset? get startPoint => _startPoint;
  Offset? get endPoint => _endPoint;

  // ── Selection State ──
  DrawnShape? _selectedShape;
  Offset? _selectionStartPoint;
  String? _selectedTextKey;
  Offset? _textDragStartPoint;

  DrawnShape? get selectedShape => _selectedShape;
  set selectedShape(DrawnShape? value) { _selectedShape = value; notifyListeners(); }

  // ── Resize State ──
  bool _isResizing = false;
  ResizeHandle _activeHandle = ResizeHandle.none;
  Offset? _resizeStartPoint;
  DrawnShape? _initialResizeShape;

  bool get isResizing => _isResizing;
  ResizeHandle get activeHandle => _activeHandle;
  double get handleRadius => config.handleRadius;

  // ── Measurement State ──
  Offset? _measurementStart;
  Offset? _measurementEnd;
  String _measurementValue = '';

  Offset? get measurementStart => _measurementStart;
  Offset? get measurementEnd => _measurementEnd;
  String get measurementValue => _measurementValue;

  // ── Canvas Transform ──
  double _canvasScale = 1.0;
  Offset _canvasOffset = Offset.zero;

  double get canvasScale => _canvasScale;
  set canvasScale(double value) {
    _canvasScale = value.clamp(config.minScale, config.maxScale);
    notifyListeners();
  }

  Offset get canvasOffset => _canvasOffset;
  set canvasOffset(Offset value) { _canvasOffset = value; notifyListeners(); }

  // ── UI Toggles ──
  bool _showGrid = true;
  bool _showPropertyPanel = true;

  bool get showGrid => _showGrid;
  set showGrid(bool value) { _showGrid = value; notifyListeners(); }

  bool get showPropertyPanel => _showPropertyPanel;
  set showPropertyPanel(bool value) { _showPropertyPanel = value; notifyListeners(); }

  // ── Snapping ──
  bool _hasSnapped = false;
  Offset? _snapStartPosition;

  // ── Suggestion State ──
  Timer? _holdTimer;
  Offset? _suggestionPosition;
  List<ShapeType>? _suggestedShapes;

  Offset? get suggestionPosition => _suggestionPosition;
  List<ShapeType>? get suggestedShapes => _suggestedShapes;

  // ── Internal ──
  Offset? _lastLineEndPoint;

  // ── Eraser State ──
  Offset? _eraserPosition;
  Offset? get eraserPosition => _eraserPosition;

  // ── Callbacks (for app-level UI) ──
  /// Called when the engine needs text input (e.g., the Text tool was tapped).
  void Function(Offset position)? onTextInputRequested;

  /// Called when a shape's text needs editing.
  void Function(DrawnShape shape)? onShapeTextEditRequested;

  /// Called when a shape is selected or deselected.
  void Function(DrawnShape? shape)? onSelectionChanged;

  /// Called when a shape is added.
  void Function(DrawnShape shape)? onShapeAdded;

  /// Called when shapes are cleared.
  VoidCallback? onShapesCleared;

  // ── Revision counter (for efficient shouldRepaint) ──
  int _revision = 0;
  int get revision => _revision;

  void _notify() {
    _revision++;
    notifyListeners();
  }

  // ════════════════ UNDO / REDO ════════════════

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Stores the current shapes for undo. Call before mutations.
  void saveStateForUndo() {
    _undoStack.add(_shapes.map((s) => s.clone()).toList());
    _redoStack.clear();

    // Enforce max stack size
    while (_undoStack.length > config.maxUndoSteps) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last action.
  void undo() {
    if (!canUndo) return;
    _redoStack.add(_shapes.map((s) => s.clone()).toList());
    _shapes..clear()..addAll(_undoStack.removeLast());
    _selectedShape = null;
    onSelectionChanged?.call(null);
    _notify();
  }

  /// Redoes the last undone action.
  void redo() {
    if (!canRedo) return;
    _undoStack.add(_shapes.map((s) => s.clone()).toList());
    _shapes..clear()..addAll(_redoStack.removeLast());
    _selectedShape = null;
    onSelectionChanged?.call(null);
    _notify();
  }

  // ════════════════ SHAPE CRUD ════════════════

  /// Adds a shape and notifies listeners.
  void addShape(DrawnShape shape) {
    _shapes.add(shape);
    onShapeAdded?.call(shape);
    _notify();
  }

  /// Removes a shape and notifies listeners.
  void removeShape(DrawnShape shape) {
    _shapes.remove(shape);
    if (_selectedShape == shape) {
      _selectedShape = null;
      onSelectionChanged?.call(null);
    }
    _notify();
  }

  /// Clears all shapes (saves undo state first).
  void clearAll() {
    saveStateForUndo();
    _shapes.clear();
    _selectedShape = null;
    _lastLineEndPoint = null;
    _measurementValue = '';
    onSelectionChanged?.call(null);
    onShapesCleared?.call();
    _notify();
  }

  /// Deletes the currently selected shape.
  void deleteSelectedShape() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    _shapes.remove(_selectedShape);
    _selectedShape = null;
    onSelectionChanged?.call(null);
    _notify();
  }

  /// Duplicates the currently selected shape with an offset.
  void duplicateSelectedShape() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    final clone = _selectedShape!.clone();
    const offset = Offset(20, 20);
    clone.start += offset;
    clone.end += offset;
    clone.textPositions = clone.textPositions.map((k, p) => MapEntry(k, p + offset));
    if (clone.pathPoints != null) {
      clone.pathPoints = clone.pathPoints!.map((p) => p + offset).toList();
    }
    _shapes.add(clone);
    _selectedShape = clone;
    onSelectionChanged?.call(clone);
    _notify();
  }

  /// Rotates the selected shape by 45°.
  void rotateSelectedShape() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    _selectedShape!.rotation += math.pi / 4;
    _notify();
  }

  bool _isSnappingEnabled = true;
  bool get isSnappingEnabled => _isSnappingEnabled;

  /// Triggers a manual refresh of the engine UI.
  void updateState() => _notify();

  /// Toggles magnetic snapping on/off.
  void toggleSnapping() {
    _isSnappingEnabled = !_isSnappingEnabled;
    _notify();
  }

  /// Moves the selected shape up one layer.
  void layerUp() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    final idx = _shapes.indexOf(_selectedShape!);
    if (idx < _shapes.length - 1) {
      _shapes.removeAt(idx);
      _shapes.insert(idx + 1, _selectedShape!);
    }
    _notify();
  }

  /// Moves the selected shape down one layer.
  void layerDown() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    final idx = _shapes.indexOf(_selectedShape!);
    if (idx > 0) {
      _shapes.removeAt(idx);
      _shapes.insert(idx - 1, _selectedShape!);
    }
    _notify();
  }

  /// Flips the selected shape horizontally.
  void flipHorizontal() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    final cx = (_selectedShape!.start.dx + _selectedShape!.end.dx) / 2;
    _selectedShape!.start = Offset(2 * cx - _selectedShape!.start.dx, _selectedShape!.start.dy);
    _selectedShape!.end = Offset(2 * cx - _selectedShape!.end.dx, _selectedShape!.end.dy);
    if (_selectedShape!.pathPoints != null) {
      _selectedShape!.pathPoints = _selectedShape!.pathPoints!.map((p) => Offset(2 * cx - p.dx, p.dy)).toList();
    }
    _notify();
  }

  /// Flips the selected shape vertically.
  void flipVertical() {
    if (_selectedShape == null) return;
    saveStateForUndo();
    final cy = (_selectedShape!.start.dy + _selectedShape!.end.dy) / 2;
    _selectedShape!.start = Offset(_selectedShape!.start.dx, 2 * cy - _selectedShape!.start.dy);
    _selectedShape!.end = Offset(_selectedShape!.end.dx, 2 * cy - _selectedShape!.end.dy);
    if (_selectedShape!.pathPoints != null) {
      _selectedShape!.pathPoints = _selectedShape!.pathPoints!.map((p) => Offset(p.dx, 2 * cy - p.dy)).toList();
    }
    _notify();
  }

  // ════════════════ SUGGESTIONS ════════════════

  /// Accepts a shape suggestion — replaces the last freehand with the recognized shape.
  void acceptSuggestion(ShapeType type) {
    if (_shapes.isEmpty) return;
    final lastShape = _shapes.last;
    final newShape = DrawnShape(lastShape.start, lastShape.end, type, color: lastShape.color, strokeWidth: lastShape.strokeWidth, mode: lastShape.mode);
    if (lastShape.pathPoints != null && lastShape.pathPoints!.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity;
      double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
      for (final p in lastShape.pathPoints!) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      newShape.start = Offset(minX, minY);
      newShape.end = Offset(maxX, maxY);
    }
    _shapes.removeLast();
    _shapes.add(newShape);
    _suggestedShapes = null;
    _suggestionPosition = null;
    _isDrawing = false;
    _notify();
  }

  /// Discards the current shape suggestion.
  void discardSuggestion() {
    if (_shapes.isNotEmpty && _shapes.last.type == ShapeType.freehand) {
      _shapes.removeLast();
    }
    _suggestedShapes = null;
    _suggestionPosition = null;
    _notify();
  }

  // ════════════════ GESTURE HANDLERS ════════════════

  /// Called when a pan gesture starts.
  void handlePanStart(Offset pos) {
    // Eraser tool
    if (_currentTool == Tool.eraser) {
      _eraseAtPoint(pos);
      return;
    }

    if (_currentTool == Tool.select) {
      // Text label dragging
      if (_selectedShape != null && _selectedShape!.textPositions.isNotEmpty) {
        for (final entry in _selectedShape!.textPositions.entries) {
          if ((entry.value - pos).distance <= 50) {
            _selectedTextKey = entry.key;
            _textDragStartPoint = pos;
            return;
          }
        }
      }
      // Resize handles
      if (_selectedShape != null && _interactionMode != InteractionMode.move) {
        for (final handle in ResizeHandle.values) {
          if (handle == ResizeHandle.none) continue;
          final corner = _selectedShape!.getCornerOffset(handle);
          if ((corner - pos).distance <= config.handleRadius + 15) {
            _activeHandle = handle;
            _isResizing = true;
            _resizeStartPoint = pos;
            _initialResizeShape = _selectedShape!.copy();
            _notify();
            return;
          }
        }
      }
      // Select shape
      final shape = _getShapeAtPoint(pos);
      if (shape != null) {
        _selectedShape = shape;
        _selectionStartPoint = pos;
        onSelectionChanged?.call(shape);
        saveStateForUndo();
      } else {
        _selectedShape = null;
        onSelectionChanged?.call(null);
      }
      _notify();
      return;
    }

    // Line chaining
    if (_currentTool == Tool.draw && _currentShape == ShapeType.line && _lastLineEndPoint != null) {
      _startPoint = (pos - _lastLineEndPoint!).distance < 20.0 ? _lastLineEndPoint : pos;
    } else {
      _startPoint = pos;
    }

    // Freehand
    if (_currentTool == Tool.draw && _currentShape == ShapeType.freehand) {
      saveStateForUndo();
      if (_suggestedShapes != null) {
        _suggestedShapes = null;
        _suggestionPosition = null;
      }
      _shapes.add(DrawnShape(pos, pos, ShapeType.freehand, pathPoints: [pos], color: _strokeColor, strokeWidth: _strokeWidth, mode: _drawMode));
      _isDrawing = true;
      _startHoldTimer(pos);
    } else {
      saveStateForUndo();
      _isDrawing = true;
      if (_currentTool == Tool.measure) {
        _measurementStart = _startPoint;
        _measurementEnd = _startPoint;
        _measurementValue = '0.00 mm';
      }
    }
    _notify();
  }

  /// Called when a pan gesture updates.
  void handlePanUpdate(Offset pos, Offset delta) {
    // Eraser tool
    if (_currentTool == Tool.eraser) {
      _eraserPosition = pos;
      _eraseAtPoint(pos);
      return;
    }

    // Pan tool
    if (_currentTool == Tool.pan) {
      _canvasOffset += delta;
      _notify();
      return;
    }

    // Text dragging
    if (_selectedTextKey != null && _selectedShape != null && _textDragStartPoint != null) {
      _selectedShape!.textPositions[_selectedTextKey!] = _selectedShape!.textPositions[_selectedTextKey!]! + (pos - _textDragStartPoint!);
      _textDragStartPoint = pos;
      _notify();
      return;
    }

    // Resize handle fallback check
    if (_currentTool == Tool.select && _selectedShape != null && !_isResizing && _interactionMode != InteractionMode.move) {
      for (final handle in ResizeHandle.values) {
        if (handle == ResizeHandle.none) continue;
        final corner = _selectedShape!.getCornerOffset(handle);
        if ((corner - pos).distance <= config.handleRadius + 15) {
          _activeHandle = handle;
          _isResizing = true;
          _resizeStartPoint = pos;
          _initialResizeShape = _selectedShape!.copy();
          _notify();
          return;
        }
      }
    }

    if (_isResizing) {
      _resizeSelectedShape(pos);
      return;
    }

    // Moving shapes
    if (_currentTool == Tool.select && _selectedShape != null && _selectionStartPoint != null) {
      if (_interactionMode == InteractionMode.resize && !_isResizing) return;

      final moveDelta = pos - _selectionStartPoint!;
      final candidateStart = _selectedShape!.start + moveDelta;
      final candidateEnd = _selectedShape!.end + moveDelta;
      
      Offset offsetToApply = moveDelta;

      if (_isSnappingEnabled) {
        final snapOffset = SnapHelper.getSnapPoint(candidateStart, candidateEnd, _selectedShape!, _shapes, config.snapThreshold);
        if (snapOffset != null) {
          if (_hasSnapped) {
            if ((pos - (_snapStartPosition ?? pos)).distance > config.detachThreshold) {
              _hasSnapped = false;
              _snapStartPosition = null;
            } else {
              offsetToApply = snapOffset;
            }
          } else {
            offsetToApply = snapOffset;
            _snapStartPosition = pos;
            _hasSnapped = true;
          }
        } else {
          _hasSnapped = false;
          _snapStartPosition = null;
        }
      }

      _selectedShape!.start += offsetToApply;
      _selectedShape!.end += offsetToApply;
      _selectedShape!.textPositions = _selectedShape!.textPositions.map((k, p) => MapEntry(k, p + offsetToApply));
      if (_selectedShape!.type == ShapeType.freehand && _selectedShape!.pathPoints != null) {
        _selectedShape!.pathPoints = _selectedShape!.pathPoints!.map((p) => p + offsetToApply).toList();
      }
      _selectionStartPoint = pos;
      _notify();
      return;
    }

    // Drawing / Measurement
    if (_currentTool == Tool.measure) {
      _measurementEnd = pos;
      final dist = (_measurementEnd! - _measurementStart!).distance;
      _measurementValue = "${dist.toStringAsFixed(2)} mm";
    }

    if (_currentTool == Tool.draw) {
      if (!_isDrawing && _currentShape == ShapeType.line) {
        Offset sPoint = pos;
        if (_isSnappingEnabled) {
          final snap = SnapHelper.getClosestSnapPoint(pos, _shapes, _selectedShape);
          if (snap != null) sPoint = snap;
        }
        _startPoint = sPoint;
        _isDrawing = true;
      }
      _endPoint = pos;
      if (_isSnappingEnabled) {
        final snapEnd = SnapHelper.getClosestSnapPoint(_endPoint!, _shapes, _selectedShape);
        if (snapEnd != null) _endPoint = snapEnd;
      }

      if (_currentShape == ShapeType.freehand && _isDrawing && _shapes.isNotEmpty && _shapes.last.type == ShapeType.freehand) {
        _shapes.last.pathPoints!.add(_endPoint!);
        _startHoldTimer(pos);
      }
    }
    _notify();
  }

  /// Called when a pan gesture ends.
  void handlePanEnd() {
    _holdTimer?.cancel();
    _eraserPosition = null;

    if (_isResizing) {
      _isResizing = false;
      _activeHandle = ResizeHandle.none;
      _resizeStartPoint = null;
      _initialResizeShape = null;
    }

    if (_currentTool == Tool.select || _currentTool == Tool.eraser) {
      _selectionStartPoint = null;
      _notify();
      return;
    }

    if (_isDrawing && _currentTool == Tool.draw && _currentShape != ShapeType.freehand) {
      final shape = DrawnShape(_startPoint!, _endPoint ?? _startPoint!, _currentShape, color: _strokeColor, strokeWidth: _strokeWidth, mode: _drawMode);
      _initTextPositions(shape);
      _shapes.add(shape);
      onShapeAdded?.call(shape);
      _lastLineEndPoint = _currentShape == ShapeType.line ? _endPoint : null;
    } else if (_isDrawing && _currentTool == Tool.draw && _currentShape == ShapeType.freehand) {
      if (_shapes.isNotEmpty && _shapes.last.pathPoints != null) {
        final points = _shapes.last.pathPoints!;
        if (config.enableSmoothing && points.length > 2) {
          _shapes.last.pathPoints = ShapeRecognizer.smoothFreehandPath(points);
        }
      }
    }

    _isDrawing = false;
    _startPoint = null;
    _endPoint = null;
    _measurementStart = null;
    _measurementEnd = null;
    _selectedTextKey = null;
    _textDragStartPoint = null;
    _notify();
  }

  /// Called on tap down events.
  void handleTapDown(Offset pos) {
    if (_currentTool == Tool.draw && _currentShape == ShapeType.text) {
      onTextInputRequested?.call(pos);
    }
    if (_currentTool == Tool.eraser) {
      _eraseAtPoint(pos);
      return;
    }
    if (_currentTool == Tool.select) {
      _selectedTextKey = null;
      final shape = _getShapeAtPoint(pos);
      if (shape != null) {
        _selectedShape = shape;
        _selectionStartPoint = pos;
        onSelectionChanged?.call(shape);
        saveStateForUndo();
      } else {
        _selectedShape = null;
        _selectedTextKey = null;
        onSelectionChanged?.call(null);
      }
      _notify();
    }
  }

  /// Called on long-press start.
  void handleLongPressStart(Offset pos) {
    final shape = _getShapeAtPoint(pos);
    if (shape != null) {
      _currentTool = Tool.select;
      _selectedShape = shape;
      _isResizing = false;
      _selectionStartPoint = pos;
      onSelectionChanged?.call(shape);
    } else {
      _currentTool = Tool.select;
      _selectedShape = null;
      onSelectionChanged?.call(null);
    }
    _notify();
  }

  /// Handles pinch-to-zoom gestures.
  void handleScaleUpdate(double scale, Offset focalPoint) {
    _canvasScale = (_canvasScale * scale).clamp(config.minScale, config.maxScale);
    _notify();
  }

  // ════════════════ INTERNAL HELPERS ════════════════

  DrawnShape? _getShapeAtPoint(Offset point) {
    for (var i = _shapes.length - 1; i >= 0; i--) {
      if (_shapes[i].contains(point)) return _shapes[i];
    }
    return null;
  }

  void _eraseAtPoint(Offset pos) {
    saveStateForUndo();
    _shapes.removeWhere((shape) {
      if (shape.type == ShapeType.freehand && shape.pathPoints != null) {
        for (final p in shape.pathPoints!) {
          if ((p - pos).distance <= config.eraserRadius) return true;
        }
        return false;
      }
      return shape.contains(pos);
    });
    _notify();
  }

  void _resizeSelectedShape(Offset currentPos) {
    if (_selectedShape == null || _initialResizeShape == null || _resizeStartPoint == null) return;
    final delta = currentPos - _resizeStartPoint!;
    _selectedShape!.start = _initialResizeShape!.start;
    _selectedShape!.end = _initialResizeShape!.end + delta;

    if (_selectedShape!.pathPoints != null) {
      final os = _initialResizeShape!.start;
      final oe = _initialResizeShape!.end;
      final dxOrig = oe.dx - os.dx;
      final dyOrig = oe.dy - os.dy;
      if (dxOrig.abs() > 0.01 && dyOrig.abs() > 0.01) {
        final sx = (_selectedShape!.end.dx - _selectedShape!.start.dx) / dxOrig;
        final sy = (_selectedShape!.end.dy - _selectedShape!.start.dy) / dyOrig;
        _selectedShape!.pathPoints = _initialResizeShape!.pathPoints!.map((p) {
          return Offset(_selectedShape!.start.dx + (p.dx - os.dx) * sx, _selectedShape!.start.dy + (p.dy - os.dy) * sy);
        }).toList();
      }
    }
    _notify();
  }

  void _startHoldTimer(Offset pos) {
    _holdTimer?.cancel();
    _holdTimer = Timer(config.holdDuration, () {
      if (_isDrawing && _currentTool == Tool.draw && _currentShape == ShapeType.freehand && _shapes.isNotEmpty) {
        final lastShape = _shapes.last;
        if (lastShape.pathPoints != null && lastShape.pathPoints!.length > 5) {
          final suggestions = ShapeRecognizer.getSuggestions(lastShape.pathPoints!);
          if (suggestions.isNotEmpty) {
            _suggestedShapes = suggestions;
            _suggestionPosition = pos;
            HapticFeedback.mediumImpact();
            _notify();
          }
        }
      }
    });
  }

  void _initTextPositions(DrawnShape shape) {
    final cx = (shape.start.dx + shape.end.dx) / 2;
    final cy = (shape.start.dy + shape.end.dy) / 2;
    switch (shape.type) {
      case ShapeType.rectangle:
        shape.textPositions = {"Top": Offset(cx, shape.start.dy), "Right": Offset(shape.end.dx, cy), "Bottom": Offset(cx, shape.end.dy), "Left": Offset(shape.start.dx, cy)};
        break;
      case ShapeType.triangle:
        shape.textPositions = {"Top": Offset(cx, shape.start.dy), "Left": Offset(shape.start.dx, shape.end.dy), "Right": Offset(shape.end.dx, shape.end.dy)};
        break;
      case ShapeType.circle:
        shape.textPositions = {"Center": Offset(cx, cy)};
        break;
      default:
        shape.textPositions = {"Center": Offset(cx, cy)};
    }
  }

  // ════════════════ EXPORT ════════════════

  /// Exports the canvas as a PNG byte array.
  ///
  /// [canvasKey] must be the key of a [RepaintBoundary] wrapping the canvas.
  /// Returns null if the rendering context is unavailable.
  Future<Uint8List?> exportAsPNG(GlobalKey canvasKey, {int pixelRatio = 1}) async {
    final context = canvasKey.currentContext;
    if (context == null) return null;
    final boundary = context.findRenderObject() as RenderRepaintBoundary;
    final size = boundary.size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    DrawingPainter.fromController(this, showGrid: false).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage((size.width * pixelRatio).toInt(), (size.height * pixelRatio).toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Serializes all shapes to a JSON string.
  String toJson() {
    return json.encode(_shapes.map((s) => s.toJson()).toList());
  }

  /// Loads shapes from a JSON string.
  void loadFromJson(String jsonString) {
    saveStateForUndo();
    final list = json.decode(jsonString) as List;
    _shapes..clear()..addAll(list.map((m) => DrawnShape.fromJson(m as Map<String, dynamic>)));
    _selectedShape = null;
    _notify();
  }

  /// Zoom controls.
  void zoomIn() => canvasScale = _canvasScale + 0.1;
  void zoomOut() => canvasScale = _canvasScale - 0.1;
  void resetView() {
    _canvasScale = 1.0;
    _canvasOffset = Offset.zero;
    _notify();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}
