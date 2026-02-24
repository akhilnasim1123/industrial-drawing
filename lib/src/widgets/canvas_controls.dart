import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/drawing_controller.dart';

/// Floating canvas controls for zoom, view reset, grid toggle, and snapping.
/// Uses a modern premium glassmorphism design.
class CanvasControls extends StatelessWidget {
  final DrawingController controller;
  const CanvasControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _btn(icon: Icons.add_rounded, onTap: controller.zoomIn, tooltip: "Zoom In"),
                  const SizedBox(height: 6),
                  // Scale display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text(
                      "${(controller.canvasScale * 100).toInt()}%", 
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  ),
                  const SizedBox(height: 6),
                  _btn(icon: Icons.remove_rounded, onTap: controller.zoomOut, tooltip: "Zoom Out"),
                  Container(
                    height: 1, width: 24, 
                    color: Colors.white.withOpacity(0.15), 
                    margin: const EdgeInsets.symmetric(vertical: 10)
                  ),
                  _btn(icon: Icons.center_focus_strong_rounded, onTap: controller.resetView, tooltip: "Reset View"),
                  const SizedBox(height: 4),
                  _btn(
                    icon: controller.isSnappingEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    onTap: controller.toggleSnapping,
                    isActive: controller.isSnappingEnabled,
                    tooltip: "Toggle Snapping",
                    activeColor: const Color(0xFFFBBF24), // Amber color for snapping
                  ),
                  const SizedBox(height: 4),
                  _btn(
                    icon: controller.showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                    onTap: () => controller.showGrid = !controller.showGrid,
                    isActive: controller.showGrid,
                    tooltip: "Toggle Grid",
                  ),
                  const SizedBox(height: 4),
                  _btn(
                    icon: controller.showPropertyPanel ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    onTap: () => controller.showPropertyPanel = !controller.showPropertyPanel,
                    isActive: controller.showPropertyPanel,
                    tooltip: controller.showPropertyPanel ? "Hide Properties Panel" : "Show Properties Panel",
                    activeColor: const Color(0xFF10B981), // Emerald color
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _btn({
    required IconData icon, 
    required VoidCallback onTap, 
    bool isActive = false, 
    String? tooltip,
    Color activeColor = const Color(0xFF3B82F6),
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: isActive ? BoxDecoration(
              border: Border.all(color: activeColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ) : null,
            child: Icon(
              icon, 
              size: 20, 
              color: isActive ? activeColor : Colors.white.withOpacity(0.7)
            ),
          ),
        ),
      ),
    );
  }
}
