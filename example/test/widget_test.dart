import 'package:flutter_test/flutter_test.dart';

import 'package:app_updater_example/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('App Updater Demo'), findsOneWidget);
  });
}
