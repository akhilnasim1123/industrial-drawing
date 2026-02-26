import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/drawing_controller.dart';
import '../models/enums.dart';

/// Modern bottom toolbar with tool selection and shape palette.
/// Designed as a premium floating glass pill.
class DrawingToolbar extends StatelessWidget {
  final DrawingController controller;
  final void Function(Tool tool)? onToolSelected;

  const DrawingToolbar({
    super.key,
    required this.controller,
    this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionLabel("TOOLS"),
                      const SizedBox(width: 8),
                      _toolBtn(Tool.select, Icons.touch_app_rounded, "Select"),
                      _toolBtn(Tool.pan, Icons.pan_tool_rounded, "Pan"),
                      _toolBtn(Tool.measure, Icons.straighten_rounded, "Measure"),
                      _toolBtn(Tool.eraser, Icons.auto_fix_normal, "Eraser"),
                      _divider(),
                      
                      _sectionLabel("BASIC"),
                      const SizedBox(width: 8),
                      _shapeBtn(ShapeType.freehand, Icons.draw_rounded, "Draw"),
                      _shapeBtn(ShapeType.line, Icons.horizontal_rule_rounded, "Line"),
                      _shapeBtn(ShapeType.arrow, Icons.north_east_rounded, "Arrow"),
                      _shapeBtn(ShapeType.rectangle, Icons.crop_square_rounded, "Rect"),
                      _shapeBtn(ShapeType.circle, Icons.circle_outlined, "Circle"),
                      _shapeBtn(ShapeType.triangle, Icons.change_history_rounded, "Tri"),
                      _shapeBtn(ShapeType.star, Icons.star_border_rounded, "Star"),
                      _shapeBtn(ShapeType.polygon, Icons.hexagon_outlined, "Poly"),
                      _shapeBtn(ShapeType.dimension, Icons.space_bar_rounded, "Dim"),
                      _shapeBtn(ShapeType.text, Icons.text_fields_rounded, "Text"),
                      
                      _divider(),
                      
                      _sectionLabel("INDUSTRIAL"),
                      const SizedBox(width: 8),
                      _shapeBtn(ShapeType.lShape, Icons.turn_right_rounded, "L-Shape"),
                      _shapeBtn(ShapeType.tShape, Icons.view_column_rounded, "T-Shape"),
                      _shapeBtn(ShapeType.uShape, Icons.video_label_rounded, "U-Shape"),
                      _shapeBtn(ShapeType.boxShape, Icons.check_box_outline_blank_rounded, "Box"),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          text, 
          style: TextStyle(
            fontSize: 8, 
            fontWeight: FontWeight.w800, 
            color: Colors.white.withValues(alpha: 0.4), 
            letterSpacing: 2.0
          )
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 36, 
      width: 1.5, 
      color: Colors.white.withValues(alpha: 0.15), 
      margin: const EdgeInsets.symmetric(horizontal: 14)
    );
  }

  Widget _toolBtn(Tool tool, IconData icon, String label) {
    final isActive = controller.currentTool == tool;
    return _animBtn(
      isActive: isActive,
      icon: icon,
      label: label,
      activeColor: const Color(0xFF3B82F6),
      onTap: () {
        controller.currentTool = tool;
        onToolSelected?.call(tool);
      }
    );
  }

  Widget _shapeBtn(ShapeType type, IconData icon, String label) {
    final isActive = controller.currentTool == Tool.draw && controller.currentShape == type;
    return _animBtn(
      isActive: isActive,
      icon: icon,
      label: label,
      activeColor: const Color(0xFF8B5CF6),
      onTap: () {
        controller.currentTool = Tool.draw;
        controller.currentShape = type;
      }
    );
  }
  
  Widget _animBtn({
    required bool isActive,
    required IconData icon,
    required String label,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? activeColor.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.5
              ),
              boxShadow: isActive ? [
                BoxShadow(color: activeColor.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 2))
              ] : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                splashColor: activeColor.withValues(alpha: 0.3),
                highlightColor: activeColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    icon, 
                    size: 22, 
                    color: isActive ? activeColor : Colors.white.withValues(alpha: 0.7)
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10, 
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, 
              color: isActive ? activeColor : Colors.white.withValues(alpha: 0.5)
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
