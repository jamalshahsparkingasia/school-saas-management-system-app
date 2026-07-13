import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:primeschoolos_app/main.dart';
import 'package:primeschoolos_app/state/session.dart';

void main() {
  testWidgets('app boots to the login screen when signed out',
      (WidgetTester tester) async {
    final session = Session()..restoring = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const PrimeSchoolApp(),
      ),
    );

    expect(find.text('Sign in'), findsOneWidget);
  });
}
