import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app_flutter/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const TissusApp());
  });
}
