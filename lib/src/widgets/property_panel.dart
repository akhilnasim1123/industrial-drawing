import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/drawing_controller.dart';
import '../models/enums.dart';
import '../models/drawn_shape.dart';

/// Side property panel with contextual controls.
/// Premium, dark glassmorphism design.
class PropertyPanel extends StatelessWidget {
  final DrawingController controller;
  final VoidCallback? onPickColor;
  final VoidCallback? onPickSelectedShapeColor;
  final VoidCallback? onEditText;

  const PropertyPanel({
    super.key,
    required this.controller,
    this.onPickColor,
    this.onPickSelectedShapeColor,
    this.onEditText,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.showPropertyPanel) return const SizedBox.shrink();

        if (controller.currentTool == Tool.draw) return _buildDrawPanel();
        if (controller.currentTool == Tool.eraser) return _buildEraserPanel();
        if (controller.selectedShape != null) return _buildSelectionPanel();
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDrawPanel() {
    return _panelContainer(
      title: "BRUSH PROPS",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _colorCircle(controller.strokeColor, onPickColor),
              const SizedBox(width: 12),
              _modeToggle(),
            ],
          ),
          const SizedBox(height: 12),
          _strokeSlider(
            value: controller.strokeWidth,
            onChanged: (v) => controller.strokeWidth = v,
            label: "Thickness",
          ),
        ],
      ),
    );
  }

  Widget _buildEraserPanel() {
    return _panelContainer(
      title: "ERASER",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_fix_normal_rounded, color: Color(0xFFEF4444), size: 28),
          ),
          const SizedBox(height: 12),
          const Text("Eraser Active", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text("Swipe over shapes\nto erase them.", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel() {
    final s = controller.selectedShape!;
    return _panelContainer(
      title: "SELECTION",
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Color & fill toggle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _colorCircle(s.color, onPickSelectedShapeColor),
                const SizedBox(width: 12),
                _miniBtn(
                  icon: s.mode == DrawMode.fill ? Icons.circle : Icons.circle_outlined,
                  isActive: s.mode == DrawMode.fill,
                  onTap: () {
                    controller.saveStateForUndo();
                    s.mode = s.mode == DrawMode.fill ? DrawMode.stroke : DrawMode.fill;
                    controller.updateState();
                  },
                  tooltip: "Toggle Fill/Stroke",
                ),
              ],
            ),
            const SizedBox(height: 12),
            _strokeSlider(
              value: s.strokeWidth,
              onChanged: (v) { s.strokeWidth = v; controller.updateState(); },
              label: "Stroke",
            ),
            const SizedBox(height: 8),
            _strokeSlider(
              value: s.opacity,
              min: 0.1,
              max: 1.0,
              onChanged: (v) { s.opacity = v; controller.updateState(); },
              label: "Opacity",
              displayValue: "${(s.opacity * 100).toInt()}%",
            ),
            if (s.type == ShapeType.polygon) ...[
              _thinDivider(),
              _strokeSlider(
                value: s.polygonSides.toDouble(),
                min: 3,
                max: 12,
                onChanged: (v) { s.polygonSides = v.toInt(); controller.updateState(); },
                label: "Sides",
                displayValue: s.polygonSides.toString(),
              ),
            ],
            _thinDivider(),
            // Numeric Geometry
            _geometryInputs(s),
            _thinDivider(),
            // Interaction modes
            _interactionModeRow(),
            const SizedBox(height: 12),
            // Action buttons in a grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _actionBtn(Icons.copy_rounded, controller.duplicateSelectedShape, "Duplicate"),
                _actionBtn(Icons.flip_rounded, controller.flipHorizontal, "Flip Horiz"),
                _actionBtn(Icons.flip_rounded, controller.flipVertical, "Flip Vert", rotateIcon: true),
                _actionBtn(Icons.flip_to_front_rounded, controller.layerUp, "Bring Forward"),
                _actionBtn(Icons.flip_to_back_rounded, controller.layerDown, "Send Backward"),
                _actionBtn(Icons.edit_note_rounded, onEditText ?? () {}, "Edit Attributes"),
                _actionBtn(Icons.rotate_right_rounded, controller.rotateSelectedShape, "Rotate 45°"),
              ],
            ),
            const SizedBox(height: 12),
            _deleteBtn(),
          ],
        ),
      ),
    );
  }

  Widget _geometryInputs(DrawnShape s) {
    final width = (s.end.dx - s.start.dx).abs();
    final height = (s.end.dy - s.start.dy).abs();
    
    return Column(
      children: [
        Text("GEOMETRY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _tinyInput("W", width.toInt().toString(), (val) {
              final newW = double.tryParse(val);
              if (newW != null) {
                controller.saveStateForUndo();
                s.end = Offset(s.start.dx + (s.end.dx >= s.start.dx ? newW : -newW), s.end.dy);
                controller.updateState();
              }
            }),
            _tinyInput("H", height.toInt().toString(), (val) {
              final newH = double.tryParse(val);
              if (newH != null) {
                controller.saveStateForUndo();
                s.end = Offset(s.end.dx, s.start.dy + (s.end.dy >= s.start.dy ? newH : -newH));
                controller.updateState();
              }
            }),
          ],
        ),
      ],
    );
  }

  Widget _tinyInput(String label, String value, Function(String) onChanged) {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08), 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1))
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
              keyboardType: TextInputType.number,
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorCircle(Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1))
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _miniBtn(icon: Icons.circle_outlined, isActive: controller.drawMode == DrawMode.stroke, onTap: () => controller.drawMode = DrawMode.stroke, tooltip: "Stroke Outline"),
          const SizedBox(width: 4),
          _miniBtn(icon: Icons.circle, isActive: controller.drawMode == DrawMode.fill, onTap: () => controller.drawMode = DrawMode.fill, tooltip: "Solid Fill"),
        ],
      ),
    );
  }

  Widget _miniBtn({required IconData icon, required bool isActive, required VoidCallback onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8), 
            child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5))
          ),
        ),
      ),
    );
  }

  Widget _strokeSlider({
    required double value,
    required void Function(double) onChanged,
    required String label,
    double min = 1,
    double max = 20,
    String? displayValue,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.bold)),
              Text(displayValue ?? value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3, 
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: const Color(0xFF3B82F6),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF3B82F6).withValues(alpha: 0.2)
              ),
              child: Slider(value: value, min: min, max: max, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactionModeRow() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePill(InteractionMode.smart, Icons.auto_awesome_rounded, "Smart Mode"),
          _modePill(InteractionMode.move, Icons.open_with_rounded, "Force Move"),
          _modePill(InteractionMode.resize, Icons.aspect_ratio_rounded, "Force Resize"),
        ],
      ),
    );
  }

  Widget _modePill(InteractionMode mode, IconData icon, String tooltip) {
    final isActive = controller.interactionMode == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => controller.interactionMode = mode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.transparent)
          ),
          child: Icon(icon, size: 16, color: isActive ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap, String tooltip, {bool rotateIcon = false}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Transform.rotate(
              angle: rotateIcon ? 1.5708 : 0, 
              child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteBtn() {
    return Material(
      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: controller.deleteSelectedShape,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF87171)),
              SizedBox(width: 8),
              Text("Delete Shape", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thinDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), 
      child: Container(height: 1, width: double.infinity, color: Colors.white.withValues(alpha: 0.1))
    );
  }

  Widget _panelContainer({required Widget child, required String title}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: 180, // slightly wider for better layout
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Title and Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white.withValues(alpha: 0.5)), overflow: TextOverflow.ellipsis),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => controller.showPropertyPanel = false,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
