import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/ui/reminder_status.dart';
import 'controller_test.dart' show FakeDevice;

void main() {
  testWidgets('diagnostics show timestamps and distinguish unanswered issues', (tester) async {
    final c = Companion(FakeDevice());
    c.reminderHealth = {
      'exactAlarms': false,
      'routines': {'r': {'lastNotificationAt': 100000, 'unanswered': 2}},
      'issues': [{'routine': 'r', 'at': 200000, 'message': 'No response recorded after three reminders.'}],
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [ReminderStatus(controller: c)]))));
    await tester.tap(find.text('Reminder status & issues'));
    await tester.pumpAndSettle();
    expect(find.text('1 recorded issues'), findsOneWidget);
    expect(find.textContaining('Last notification:'), findsOneWidget);
    expect(find.textContaining('Unanswered attempts: 2'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('No response recorded after three reminders.'), findsOneWidget);
    c.dispose();
  });
}
