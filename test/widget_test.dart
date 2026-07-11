import 'package:flutter_test/flutter_test.dart';
import 'package:thaical/main.dart';

void main() {
  testWidgets('Smoke test - Verify Thai Calc Pro loads Login Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ThaiCalcProApp());

    // Verify that the login tab is present.
    expect(find.text('لগইন'), findsNothing); // It will be in Bengali (লগইন)
    expect(find.text('লগইন'), findsOneWidget);
    expect(find.text('সরাসরি প্রবেশ করুন (Bypass Flow)'), findsOneWidget);
  });
}
