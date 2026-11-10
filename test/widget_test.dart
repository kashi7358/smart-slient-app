import 'package:flutter_test/flutter_test.dart';
import 'package:smart_silent/main.dart';

void main() {
  testWidgets('Smart Silent App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame with onboarding fallback
    await tester.pumpWidget(const MyApp(showHome: false));

    // Verify that MyApp builds successfully
    expect(find.byType(MyApp), findsOneWidget);
  });
}
