import 'package:billeasy/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Material shell renders with localization context', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      LanguageProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) =>
                Scaffold(body: Text(AppStrings.of(context).loginWelcome)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
