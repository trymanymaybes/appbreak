import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/ui/day_planner.dart';
import 'controller_test.dart' show FakeDevice;
import 'calendar_history_test.dart' show shell;

void main() {
  testWidgets('day blocks show overlaps, routine details and saved mode', (
    tester,
  ) async {
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final device = FakeDevice()
      ..value = {
        'settings': {'plannerView': 'day'},
        'plans': [
          for (var i = 0; i < 2; i++)
            {
              'id': 'p$i',
              'title': 'Reading $i',
              'date': day,
              'minute': 420,
              'minutes': 60,
              'days': [],
              'routine': 'short',
            },
        ],
      };
    final c = Companion(device)..data = device.value;
    await tester.pumpWidget(shell(c, DayPlanner(controller: c)));
    expect(find.byKey(const ValueKey('planner-timeline')), findsOneWidget);
    final a = tester.getRect(find.byKey(const ValueKey('timeline-p0')));
    final b = tester.getRect(find.byKey(const ValueKey('timeline-p1')));
    expect(a.top, b.top);
    expect(a.right, lessThan(b.left));
    await tester.ensureVisible(find.byKey(const ValueKey('timeline-p0')));
    await tester.tap(find.byKey(const ValueKey('timeline-p0')));
    await tester.pumpAndSettle();
    expect(find.text('Planned activity'), findsOneWidget);
    expect(find.textContaining('min break'), findsWidgets);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('List'));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(c.settings['plannerView'], 'list');
    expect(find.byKey(const ValueKey('planner-timeline')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'short overlapping plans fit at 200 percent text and retain accessible labels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      final day = DateTime.now().toIso8601String().substring(0, 10);
      final c = Companion(FakeDevice())
        ..data = {
          'settings': {'plannerView': 'day'},
          'plans': [
            for (var i = 0; i < 3; i++)
              {
                'id': 'p$i',
                'title': 'Long activity title $i',
                'date': day,
                'minute': 360,
                'minutes': 1,
                'days': [],
                'routine': 'removed',
              },
          ],
        };
      await tester.pumpWidget(shell(c, DayPlanner(controller: c), scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('Long activity title 0.*removed')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      semantics.dispose();
    },
  );
}
