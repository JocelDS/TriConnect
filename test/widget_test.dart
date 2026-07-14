import 'package:flutter_test/flutter_test.dart';
import 'package:triconnect/main.dart';

void main() {
  testWidgets('welcome screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('GET STARTED'), findsOneWidget);
  });
}
