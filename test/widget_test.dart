import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca_lucca/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BibliotecaLuccaApp());
    expect(find.text('Biblioteca de Lucca'), findsOneWidget);
  });
}
