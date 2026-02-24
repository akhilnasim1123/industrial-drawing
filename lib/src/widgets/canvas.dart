import 'package:flutter/material.dart';
import '../controllers/drawing_controller.dart';
import '../painters/drawing_painter.dart';

/// The core interactive drawing surface.
///
/// Binds gesture input to the [DrawingController] and renders via [DrawingPainter].
/// Uses [RepaintBoundary] for efficient repaint isolation and export capability.
class DrawingCanvas extends StatelessWidget {
  /// The controller that manages all drawing state.
  final DrawingController controller;

  /// A [GlobalKey] for the [RepaintBoundary] — required for PNG export.
  final GlobalKey canvasKey;

  /// Optional background color for the canvas.
  final Color backgroundColor;

  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.canvasKey,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return RepaintBoundary(
          key: canvasKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => controller.handlePanStart(d.localPosition),
            onPanUpdate: (d) => controller.handlePanUpdate(d.localPosition, d.delta),
            onPanEnd: (_) => controller.handlePanEnd(),
            onTapDown: (d) => controller.handleTapDown(d.localPosition),
            onLongPressStart: (d) => controller.handleLongPressStart(d.localPosition),
            child: CustomPaint(
              painter: DrawingPainter.fromController(controller),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}
