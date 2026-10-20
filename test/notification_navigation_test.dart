import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class NotificationDevice extends FakeDevice {
  Map<String, dynamic>? open;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'consumeBreakOpen') {
      final result = open;
      open = null;
      return result as T?;
    }
    if (method == 'allowed') return false as T;
    return null;
  }
}

NotificationDevice deviceWith(Phase phase) {
  final d = NotificationDevice();
  d.value['session'] = const Session(id: 'break')
      .at(phase, 60000, const Moment(100000, 1000, 1), activityId: 'quiet.soft')
      .toJson();
  return d;
}

void main() {
  for (final phase in [Phase.rest, Phase.pending, Phase.finished]) {
    testWidgets('warm notification routes from Settings for ${phase.name}', (
      tester,
    ) async {
      final d = deviceWith(phase);
      final c = ReadyCompanion(d);
      await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      d.open = {'sessionId': 'break'};
      await c.refresh();
      await tester.pumpAndSettle();
      expect(
        find.text(
          phase == Phase.pending
              ? 'Did you take your break?'
              : phase == Phase.finished
              ? 'Break time ended'
              : 'Take a little space',
        ),
        findsOneWidget,
      );
      expect(c.session.id, 'break');
      expect(c.session.phase, phase);
      expect(c.breakNavigationVersion, 1);
      await c.refresh();
      expect(
        c.breakNavigationVersion,
        1,
      ); // consumed once, no repeated navigation
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('cold tap starts the due break despite quiet reminder hours', (
    tester,
  ) async {
    final d = deviceWith(Phase.due)..open = {'sessionId': 'break'};
    final c = ReadyCompanion(d);
    await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
    await tester.pumpAndSettle();
    expect(c.session.phase, Phase.rest);
    expect(find.text('Take a little space'), findsOneWidget);
    expect(c.breakNavigationVersion, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'stale tap neither routes nor resets a different active session',
    (tester) async {
      final d = deviceWith(Phase.rest);
      final c = ReadyCompanion(d);
      await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      d.open = {'sessionId': 'old-break'};
      await c.refresh();
      await tester.pumpAndSettle();
      expect(c.breakNavigationVersion, 0);
      expect(c.session.id, 'break');
      expect(c.session.remaining(c.moment), 60000);
      expect(find.text('Take a little space'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
