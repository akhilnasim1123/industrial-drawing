import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_drawing_flutter/industrial_drawing_flutter.dart';

void main() {
  test('DrawingController initializes cleanly', () {
    final controller = DrawingController();
    // Test that the controller starts with no shapes
    expect(controller.drawnShapes.length, 0);
  });
}
