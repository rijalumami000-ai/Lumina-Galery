import 'package:flutter_test/flutter_test.dart';
import 'package:galeri_foto/main.dart';

void main() {
  testWidgets('Lumina Gallery smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LuminaGalleryApp());

    // Verify that we see the app name
    expect(find.text('Lumina'), findsOneWidget);
  });
}
