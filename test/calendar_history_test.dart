import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/break_counts.dart';
import 'package:appbreak/ui/day_planner.dart';
import 'package:appbreak/ui/break_history.dart';
import 'controller_test.dart' show FakeDevice;

Widget shell(Companion c, Widget child, {double scale = 1}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: AnimatedBuilder(
      animation: c,
      builder: (_, _) => SingleChildScrollView(child: child),
    ),
  ),
);
void main() {
  testWidgets(
    'calendar selects dates, includes recurrence and remembers list mode',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final next = DateTime(now.year, now.month + 1, 1);
      String date(DateTime d) => d.toIso8601String().substring(0, 10);
      final d = FakeDevice()
        ..value = {
          'plans': [
            {
              'id': 'one',
              'title': 'Today plan',
              'date': date(today),
              'minute': 600,
              'minutes': 30,
              'days': [],
              'routine': 'short',
            },
            {
              'id': 'repeat',
              'title': 'Recurring plan',
              'date': date(next),
              'minute': 660,
              'minutes': 30,
              'days': [next.weekday],
              'routine': 'short',
            },
          ],
        };
      final c = Companion(d)..data = d.value;
      await tester.pumpWidget(shell(c, DayPlanner(controller: c)));
      expect(find.byKey(const ValueKey('planner-calendar')), findsOneWidget);
      expect(find.text('Today plan'), findsOneWidget);
      expect(find.text('Recurring plan'), findsNothing);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('Recurring plan'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('calendar-${date(next)}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('planner-calendar')), findsNothing);
      expect(find.text('Recurring plan'), findsOneWidget);
      expect(c.settings['plannerView'], 'list');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('calendar fits narrow viewport at 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final c = Companion(FakeDevice());
    await tester.pumpWidget(shell(c, DayPlanner(controller: c), scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'past records collapse, filter removed activities, and show saved local time',
    (tester) async {
      final c = Companion(FakeDevice())
        ..data = {
          'history': [
            {
              'id': 'a',
              'activity': 'removed',
              'title': 'Saved imagination',
              'category': 'imagination',
              'date': '2026-10-23',
              'recordedAt': DateTime.parse(
                '2026-10-23T08:15:00Z',
              ).millisecondsSinceEpoch,
              'utcOffsetMinutes': 330,
            },
            {
              'id': 'b',
              'activity': 'quiet.soft',
              'title': 'Quiet rest',
              'category': 'quiet',
              'date': '2026-10-22',
            },
          ],
        };
      await tester.pumpWidget(shell(c, BreakHistory(controller: c)));
      expect(find.text('Completed • Saved imagination'), findsNothing);
      await tester.tap(find.text('Past records (2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1:45 PM'), findsOneWidget);
      expect(find.textContaining('Time not recorded'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved imagination').last);
      await tester.pumpAndSettle();
      expect(find.text('Completed • Saved imagination'), findsOneWidget);
      expect(find.text('Completed • Quiet rest'), findsNothing);
      await tester.ensureVisible(find.text('2026-10-23 (1)'));
      await tester.tap(find.text('2026-10-23 (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Completed • Saved imagination'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  test(
    'records sort by saved time within a date, without inventing legacy time',
    () {
      final rows = breakRecords(
        [
          {'id': 'old', 'date': '2026-10-23'},
          {'id': 'early', 'date': '2026-10-23', 'recordedAt': 1000},
          {'id': 'late', 'date': '2026-10-23', 'recordedAt': 2000},
        ],
        [],
        [],
      );
      expect(rows.map((r) => r['id']), ['late', 'early', 'old']);
      expect(rows.last.containsKey('recordedAt'), isFalse);
    },
  );
  test('late confirmation retains the original timestamp and offset', () async {
    final d = FakeDevice()
      ..value = {
        'missedBreaks': [
          {
            'id': 'a',
            'date': '2026-10-23',
            'reason': 'unconfirmed',
            'recordedAt': 1234,
            'utcOffsetMinutes': 330,
          },
        ],
      };
    final c = Companion(d);
    await c.confirmArchivedBreak('a');
    expect(c.history.single['recordedAt'], 1234);
    expect(c.history.single['utcOffsetMinutes'], 330);
    expect(c.history.single['confirmedAt'], 100000);
    c.dispose();
  });
}
