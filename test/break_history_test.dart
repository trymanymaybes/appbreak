import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'historical confirmation is idempotent and preserves current session',
    () async {
      final d = FakeDevice();
      final active = const Session(
        id: 'new',
      ).at(Phase.rest, 60000, const Moment(100000, 1000, 1));
      d.value = {
        'session': active.toJson(),
        'missedBreaks': [
          {
            'id': 'old',
            'routineId': 'r',
            'activity': 'removed',
            'date': '2026-10-18',
            'reason': 'unconfirmed',
          },
        ],
      };
      final c = Companion(d);
      await c.confirmArchivedBreak('old');
      await c.confirmArchivedBreak('old');
      expect(c.session.toJson(), active.toJson());
      expect(c.history.length, 1);
      expect(c.history.single['date'], '2026-10-18');
      expect(c.missedBreaks, isEmpty);
      c.dispose();
    },
  );
  test(
    'leaving a break preserves its deadline and skip records no completion',
    () async {
      final d = FakeDevice();
      d.value = {
        'session': const Session(
          id: 'old',
          activity: 'quiet.soft',
        ).at(Phase.rest, 60000, const Moment(100000, 1000, 1)).toJson(),
      };
      final c = Companion(d);
      await c.leaveBreak();
      expect(c.session.phase, Phase.pending);
      expect(c.session.elapsedDue, 61000);
      await c.cancel();
      expect(c.history, isEmpty);
      expect(c.missedBreaks.single['reason'], 'skipped');
      expect(c.session.phase, Phase.idle);
      c.dispose();
    },
  );
  testWidgets('Achievements shows completed and missed without gamification', (
    tester,
  ) async {
    final c = ReadyCompanion(FakeDevice());
    c.data = {
      'settings': {'gamification': false},
      'history': [
        {'id': 'done', 'date': '2026-10-18', 'category': 'quiet'},
      ],
      'missedBreaks': [
        {'id': 'old', 'date': '2026-10-19', 'reason': 'unconfirmed'},
      ],
    };
    await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Achievements'));
    await tester.pumpAndSettle();
    expect(find.text('Break dashboard'), findsOneWidget);
    expect(find.text('1 completed • 1 missed'), findsOneWidget);
    expect(find.text('I took it'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
