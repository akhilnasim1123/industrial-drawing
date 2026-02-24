import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/drawing_controller.dart';

/// Top header bar with title, undo/redo, save, share, and clear actions.
/// Designed as a floating glassmorphic pill.
class DrawingHeader extends StatelessWidget {
  final DrawingController controller;
  final String title;
  final TextStyle? titleStyle;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onClear;

  /// Optional leading widget (e.g., a back button).
  final Widget? leading;

  /// Additional trailing actions.
  final List<Widget>? extraActions;

  const DrawingHeader({
    super.key,
    required this.controller,
    this.title = 'Industrial Drawing',
    this.titleStyle,
    this.onSave,
    this.onShare,
    this.onClear,
    this.leading,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    // Leading
                    if (leading != null) leading!
                    else if (Navigator.canPop(context)) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.white,
                        splashRadius: 20,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Title
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle ?? const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Shape count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Text(
                        "${controller.drawnShapes.length}",
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Actions
                    _headerBtn(
                      icon: Icons.undo_rounded,
                      onTap: controller.canUndo ? controller.undo : null,
                      tooltip: "Undo (${controller.undoCount})",
                    ),
                    _headerBtn(
                      icon: Icons.redo_rounded,
                      onTap: controller.canRedo ? controller.redo : null,
                      tooltip: "Redo (${controller.redoCount})",
                    ),
                    const SizedBox(width: 4),

                    if (onSave != null)
                      _headerBtn(icon: Icons.save_alt_rounded, onTap: onSave, tooltip: "Save"),
                    if (onShare != null)
                      _headerBtn(icon: Icons.ios_share_rounded, onTap: onShare, tooltip: "Share"),

                    if (extraActions != null) ...extraActions!,

                    if (onClear != null)
                      _headerBtn(icon: Icons.delete_outline_rounded, onTap: onClear, tooltip: "Clear All", destructive: true),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerBtn({required IconData icon, VoidCallback? onTap, String? tooltip, bool destructive = false}) {
    final enabled = onTap != null;
    final color = destructive 
        ? (enabled ? const Color(0xFFFF4D4D) : const Color(0xFFFF4D4D).withOpacity(0.3))
        : (enabled ? Colors.white : Colors.white.withOpacity(0.3));

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}
