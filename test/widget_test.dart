import 'package:flutter_test/flutter_test.dart';
import 'package:market/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafordApp());
    expect(find.text('Traford Farm Fresh'), findsAny);
  });
}
