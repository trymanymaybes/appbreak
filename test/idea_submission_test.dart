import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/ui/many_maybes.dart';
import 'controller_test.dart' show FakeDevice;

class SubmissionDevice extends FakeDevice {
  String? exportResult;
  final calls = <Map<String, dynamic>>[];
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    calls.add({'method': method, ...?args});
    return (method == 'saveIdeaCard' ? exportResult : null) as T?;
  }
}

void main() {
  for (final saved in [false, true]) {
    testWidgets('submission requires successful card save: $saved', (
      tester,
    ) async {
      final d = SubmissionDevice()..exportResult = saved ? 'Saved' : null;
      final c = Companion(d);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => submitIdea(context, c, {
                  'activity': 'manymaybes.challenge-03',
                  'text': 'My idea',
                }),
                child: const Text('Submit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(d.calls, isEmpty);
      FilledButton button() => tester.widget(
        find.widgetWithText(FilledButton, '2. Open submission'),
      );
      expect(button().onPressed, isNull);
      await tester.tap(find.text('1. Save idea card'));
      await tester.pumpAndSettle();
      expect(d.calls.single, {
        'method': 'saveIdeaCard',
        'text': 'My idea',
        'challenge': '03',
      });
      if (saved) {
        expect(button().onPressed, isNotNull);
        await tester.tap(find.text('2. Open submission'));
        await tester.pumpAndSettle();
        expect(
          d.calls.last['url'],
          'https://trymanymaybes.github.io/submit.html?challenge=03',
        );
      } else {
        expect(button().onPressed, isNull);
      }
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
