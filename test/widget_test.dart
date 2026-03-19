import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/modals/line_item.dart';
import 'package:billeasy/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen shows streamed invoices', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();

    final sampleInvoices = [
      Invoice(
        id: 'test-1',
        ownerId: 'owner-123',
        invoiceNumber: 'BR-${now.year}-00101',
        clientId: 'akash-traders-mumbai',
        clientName: 'Akash Traders',
        items: const [
          LineItem(
            description: 'Thermal paper rolls',
            quantity: 10,
            unitPrice: 120,
          ),
        ],
        createdAt: now,
        status: InvoiceStatus.paid,
      ),
    ];

    await tester.pumpWidget(
      LanguageProvider(
        child: MaterialApp(
          home: HomeScreen(
            invoicesStream: Stream<List<Invoice>>.value(sampleInvoices),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
