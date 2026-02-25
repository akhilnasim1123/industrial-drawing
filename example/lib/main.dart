import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:industrial_drawing_flutter/industrial_drawing_flutter.dart';

void main() {
  runApp(const IndustrialDrawingApp());
}

class IndustrialDrawingApp extends StatelessWidget {
  const IndustrialDrawingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Industrial Drawing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4361EE),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const DrawingScreen(),
    );
  }
}

/// The main drawing screen — assembles all engine widgets
/// and provides app-level features (color picker, text dialogs, save/share).
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});
  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final DrawingController _controller = DrawingController(
    config: const DrawingConfig(
      maxUndoSteps: 80,
      enableSmoothing: true,
    ),
  );
  final GlobalKey _canvasKey = GlobalKey();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.onTextInputRequested = _showTextDialog;
    _controller.onSelectionChanged = (shape) {
      // Optional: analytics or logging
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ════════════════ DIALOGS ════════════════

  void _pickColor() {
    Color temp = _controller.strokeColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pick a Color', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: ColorPicker(pickerColor: temp, onColorChanged: (c) => temp = c)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { _controller.strokeColor = temp; Navigator.pop(ctx); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4361EE)),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _pickSelectedShapeColor() {
    if (_controller.selectedShape == null) return;
    Color temp = _controller.selectedShape!.color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Shape Color', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: ColorPicker(pickerColor: temp, onColorChanged: (c) => temp = c)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _controller.saveStateForUndo();
              _controller.selectedShape!.color = temp;
              _controller.updateState();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4361EE)),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _showTextDialog(Offset position) {
    final tc = TextEditingController();
    double fontSize = 18;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setStateSB) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add Text", style: TextStyle(color: Color(0xFF4361EE), fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tc, autofocus: true, decoration: InputDecoration(hintText: "Enter text", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("Size: ", style: TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(child: Slider(value: fontSize, min: 10, max: 40, divisions: 6, label: fontSize.toStringAsFixed(0), onChanged: (v) => setStateSB(() => fontSize = v))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                if (tc.text.isEmpty) return;
                _controller.saveStateForUndo();
                _controller.drawnShapes.add(DrawnShape(position, position, ShapeType.text, texts: {"Center": tc.text}, textPositions: {"Center": position}, color: _controller.strokeColor, strokeWidth: _controller.strokeWidth, fontSize: fontSize));
                _controller.updateState();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4361EE)),
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditShapeTextDialog() {
    final shape = _controller.selectedShape;
    if (shape == null) return;

    List<String> positions;
    String selectedSide;
    switch (shape.type) {
      case ShapeType.rectangle: positions = ["Top", "Right", "Bottom", "Left"]; selectedSide = "Top"; break;
      case ShapeType.triangle: positions = ["Top", "Left", "Right"]; selectedSide = "Top"; break;
      case ShapeType.circle: positions = ["Center"]; selectedSide = "Center"; break;
      default: positions = ["Center"]; selectedSide = "Center";
    }

    final tc = TextEditingController(text: shape.texts[selectedSide] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Text Labels", style: TextStyle(color: Color(0xFF4361EE), fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                children: positions.map((pos) {
                  final icon = _iconForSide(pos);
                  return IconButton(
                    icon: Icon(icon, color: selectedSide == pos ? const Color(0xFF4361EE) : Colors.black54),
                    tooltip: pos,
                    onPressed: () => setStateD(() {
                      shape.texts[selectedSide] = tc.text;
                      selectedSide = pos;
                      tc.text = shape.texts[selectedSide] ?? "";
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10), const Divider(),
              TextField(controller: tc, autofocus: true, decoration: InputDecoration(hintText: "Enter text", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                _controller.saveStateForUndo();
                shape.texts[selectedSide] = tc.text;
                final rect = Rect.fromPoints(shape.start, shape.end);
                const pad = 20.0;
                Offset offset;
                switch (selectedSide) {
                  case "Top": offset = Offset(rect.center.dx, rect.top - pad - 5); break;
                  case "Bottom": offset = Offset(rect.center.dx, rect.bottom + pad - 15); break;
                  case "Left": offset = Offset(rect.left - pad - 20, rect.center.dy); break;
                  case "Right": offset = Offset(rect.right + pad - 15, rect.center.dy); break;
                  default: offset = rect.center;
                }
                shape.textPositions[selectedSide] = offset;
                _controller.updateState();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4361EE)),
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForSide(String side) {
    switch (side) {
      case "Top": return Icons.arrow_upward;
      case "Bottom": return Icons.arrow_downward;
      case "Left": return Icons.arrow_back;
      case "Right": return Icons.arrow_forward;
      case "Center": return Icons.circle;
      default: return Icons.crop_square;
    }
  }

  Future<void> _handleSave() async {
    if (_controller.drawnShapes.isEmpty) {
      _showSnackBar("Canvas is empty!", isError: true);
      return;
    }
    final confirmed = await _showConfirmDialog(
      title: "Save Drawing",
      message: "Save the current drawing locally?",
      confirmText: "Save",
      confirmColor: const Color(0xFF4361EE),
    );
    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        final pngBytes = await _controller.exportAsPNG(_canvasKey, pixelRatio: 2);
        if (pngBytes == null) throw Exception("Failed to export canvas");
        final dir = await getTemporaryDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        await File('${dir.path}/drawing_$ts.png').writeAsBytes(pngBytes);
        await File('${dir.path}/drawing_$ts.json').writeAsString(_controller.toJson());
        if (mounted) _showSnackBar("Drawing saved successfully! ✓");
      } catch (e) {
        if (mounted) _showSnackBar("Error: $e", isError: true);
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleShare() async {
    if (_controller.drawnShapes.isEmpty) {
      _showSnackBar("Canvas is empty!", isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final pngBytes = await _controller.exportAsPNG(_canvasKey, pixelRatio: 2);
      if (pngBytes == null) throw Exception("Failed to export canvas");
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/drawing_${DateTime.now().millisecondsSinceEpoch}.png').writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(file.path)], text: "Check out my industrial drawing!");
    } catch (e) {
      if (mounted) _showSnackBar("Error: $e", isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleClear() async {
    if (_controller.drawnShapes.isEmpty) return;
    final confirmed = await _showConfirmDialog(
      title: "Clear Canvas",
      message: "Are you sure? This will clear all shapes.",
      confirmText: "Clear All",
      confirmColor: const Color(0xFFE63946),
    );
    if (confirmed == true) _controller.clearAll();
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? const Color(0xFFE63946) : const Color(0xFF4361EE),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════ UI ════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _showConfirmDialog(
          title: "Exit Drawing?",
          message: "Any unsaved changes will be lost.",
          confirmText: "Exit",
          confirmColor: const Color(0xFFEF4444),
        );
        if (shouldPop ?? false) { if (mounted) Navigator.pop(context); }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Dark slate bg
        body: Stack(
          children: [
            // 1) The main canvas spans the entire screen
            DrawingCanvas(controller: _controller, canvasKey: _canvasKey),
            
            // 2) UI Overlays
            SafeArea(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => Stack(
                  children: [
                    // Suggestions overlay mapping (Hold to draw)
                    if (_controller.suggestedShapes != null && _controller.suggestionPosition != null)
                      Positioned(
                        top: _controller.suggestionPosition!.dy - 60,
                        left: _controller.suggestionPosition!.dx - 80,
                        child: _buildSuggestionBar(),
                      ),

                    // Measurement overlay
                    if (_controller.measurementValue.isNotEmpty)
                      Positioned(
                        top: 80, left: 0, right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                            ),
                            child: Text(
                              "📏 ${_controller.measurementValue}", 
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF38BDF8), fontSize: 13, letterSpacing: 0.5)
                            ),
                          )
                        ),
                      ),

                    // Canvas controls (Left side floating)
                    Positioned(
                      left: 16, 
                      top: 80, 
                      child: CanvasControls(controller: _controller)
                    ),

                    // Property panel (Right side floating)
                    Positioned(
                      right: 16, 
                      top: 80, 
                      child: PropertyPanel(
                        controller: _controller,
                        onPickColor: _pickColor,
                        onPickSelectedShapeColor: _pickSelectedShapeColor,
                        onEditText: _showEditShapeTextDialog,
                      )
                    ),

                    // Bottom toolbar (bottom anchored)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DrawingToolbar(controller: _controller),
                    ),

                    // Header floating on top (MUST BE LAST to be on top layer)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: DrawingHeader(
                        controller: _controller,
                        title: 'Industrial Drawing',
                        onSave: _handleSave,
                        onShare: _handleShare,
                        onClear: _handleClear,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._controller.suggestedShapes!.map((type) => IconButton(
                icon: Icon(_iconForShape(type), size: 20, color: Colors.white.withOpacity(0.9)),
                tooltip: type.name,
                onPressed: () => _controller.acceptSuggestion(type),
                splashRadius: 18,
              )),
              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 4)),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFF87171)),
                onPressed: _controller.discardSuggestion,
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForShape(ShapeType type) {
    switch (type) {
      case ShapeType.line: return Icons.horizontal_rule_rounded;
      case ShapeType.rectangle: return Icons.crop_square_rounded;
      case ShapeType.circle: return Icons.circle_outlined;
      case ShapeType.triangle: return Icons.change_history_rounded;
      case ShapeType.arrow: return Icons.north_east_rounded;
      case ShapeType.star: return Icons.star_outline_rounded;
      case ShapeType.polygon: return Icons.hexagon_outlined;
      default: return Icons.help_outline_rounded;
    }
  }
}
