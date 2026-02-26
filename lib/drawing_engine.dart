/// # Industrial Drawing Engine
///
/// A modular, CustomPainter-based drawing engine for Flutter.
///
/// ## Features
/// - 14 shape types (freehand, line, arrow, rectangle, circle, triangle,
///   star, polygon, dimension, text, L/T/U/box shapes)
/// - Select, move, resize, rotate, duplicate, flip, delete shapes
/// - Eraser tool with configurable radius
/// - Measurement tool with distance readout
/// - Shape recognition from freehand strokes
/// - Smart snapping to other shapes
/// - Bounded undo/redo with configurable max depth
/// - JSON serialization/deserialization
/// - PNG export with configurable pixel ratio
/// - Fully customizable: no dependency on flutter_colorpicker or
///   any specific dialog/UI library
///
/// ## Quick Start
/// ```dart
/// import 'package:industrial_drawing_flutter/drawing_engine.dart';
///
/// final controller = DrawingController(
///   config: DrawingConfig(maxUndoSteps: 100),
/// );
///
/// // In your widget tree:
/// DrawingCanvas(controller: controller, canvasKey: GlobalKey())
/// ```
library;

// Models
export 'src/models/enums.dart';
export 'src/models/drawn_shape.dart';

// Controller
export 'src/controllers/drawing_controller.dart';

// Helpers
export 'src/helpers/shape_recognition.dart';
export 'src/helpers/snap_helpers.dart';

// Painter
export 'src/painters/drawing_painter.dart';

// Widgets
export 'src/widgets/canvas.dart';
export 'src/widgets/drawing_toolbar.dart';
export 'src/widgets/property_panel.dart';
export 'src/widgets/canvas_controls.dart';
export 'src/widgets/drawing_header.dart';
