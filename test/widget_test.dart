import 'package:file_vault/screens/sign_in_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_supabase.dart';

void main() {
  testWidgets('sign-in screen signs in', (WidgetTester tester) async {
    final server = FakeSupabase()..users['me@example.com'] = 'account-pw';
    final auth = server.auth();
    await tester.runAsync(auth.init);
    await tester.pumpWidget(MaterialApp(home: SignInScreen(auth: auth)));

    await tester.enterText(find.byType(TextField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Invalid login credentials'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'account-pw');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(auth.isSignedIn, isTrue);
  });
}
