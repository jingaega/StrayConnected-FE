import 'package:flutter_test/flutter_test.dart';
import 'package:strayconnected/strayconnected.dart';

void main() {
  testWidgets('StrayConnected loads login screen', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const StrayConnectedApp());

    // Check that the login screen text appears
    expect(find.text('StrayConnected'), findsWidgets);
  });
}
