import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/profile.dart';
import 'package:appbreak/ui/activities.dart';
import 'controller_test.dart' show FakeDevice;

Future<void> add(Companion c, String title) => c.savePersonalActivity(
  title: title,
  instructions: 'Take a quiet pause.',
  category: 'quiet',
  seconds: 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'three personal slots persist, edit at limit, delete and reuse',
    () async {
      final d = FakeDevice();
      final c = Companion(d);
      await add(c, 'One');
      await add(c, 'Two');
      await add(c, 'Three');
      expect(c.personalActivityIds.length, 3);
      await add(c, 'Four');
      expect(c.error, contains('up to 3'));
      expect((d.value['customActivities'] as List).length, 3);
      final first = c.personalActivityIds.first;
      await c.savePersonalActivity(
        id: first,
        title: 'Edited',
        instructions: 'Rest',
        category: 'quiet',
        seconds: 45,
      );
      expect(c.error, isNull);
      expect(c.activities.firstWhere((a) => a.id == first).title, 'Edited');
      await c.deletePersonalActivity(first);
      await add(c, 'Replacement');
      final restored = Companion(d);
      await restored.refresh();
      expect(restored.personalActivityIds.length, 3);
      expect(restored.activities.any((a) => a.id == first), isFalse);
      expect(
        fittingActivities(restored.activities, {
          'categories': ['quiet'],
        }, 30).length,
        3,
      );
      restored.dispose();
      c.dispose();
    },
  );
  test(
    'duration overrides survive source updates and restart, and reset',
    () async {
      final d = FakeDevice();
      final c = Companion(d);
      final a = Activity({
        'schemaVersion': 1,
        'id': 'test.quiet',
        'title': 'Quiet',
        'category': 'quiet',
        'estimatedSeconds': 60,
        'steps': [
          {'kind': 'instruction', 'text': 'Rest'},
        ],
      });
      c.bundled = [a];
      await c.refresh();
      await c.setActivityDuration(a.id, 20);
      expect(
        fittingActivities(c.activities, {
          'categories': ['quiet'],
        }, 30).length,
        1,
      );
      c.bundled = [
        Activity({...a.data, 'estimatedSeconds': 90}),
      ];
      await c.refresh();
      expect(c.activities.single.seconds, 20);
      final restored = Companion(d)..bundled = c.bundled;
      await restored.refresh();
      expect(restored.activities.single.seconds, 20);
      await restored.setActivityDuration(a.id, null);
      expect(restored.activities.single.seconds, 90);
      await restored.setActivityDuration(a.id, 301);
      expect(restored.error, isNotNull);
      expect(restored.activities.single.seconds, 90);
      restored.dispose();
      c.dispose();
    },
  );
  test(
    'failed saves report failure and do not consume a slot on disk',
    () async {
      final d = FakeDevice();
      final c = Companion(d);
      await c.refresh();
      d.fail = true;
      await add(c, 'Unsaved');
      expect(c.error, contains('disk full'));
      expect(d.value['customActivities'], isNull);
      c.dispose();
    },
  );
  testWidgets('create form validates and adds a break to the screen', (
    tester,
  ) async {
    final c = Companion(FakeDevice());
    await c.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: c,
            builder: (context, _) =>
                SingleChildScrollView(child: ActivitiesPanel(controller: c)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create custom break (0/3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'My pause',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instructions'),
      'Look away for a moment.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('My pause'), findsOneWidget);
    expect(find.text('Create custom break (1/3)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
