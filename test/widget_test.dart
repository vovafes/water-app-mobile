import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WaterApp());
    expect(find.byType(WaterApp), findsOneWidget);
  });
}
