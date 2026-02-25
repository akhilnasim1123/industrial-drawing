
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const IndustrialDrawingApp());

    // Verify that the Industrial Drawing title is present.
    expect(find.text('Industrial Drawing'), findsOneWidget);
  });
}
