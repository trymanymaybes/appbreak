// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/session.dart';
import 'controller_test.dart' show FakeDevice;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Companion companion(FakeDevice d) => Companion(d)
    ..activities =
        (jsonDecode(
                  File('assets/activities.json').readAsStringSync(),
                )['activities']
                as List)
            .map((a) => Activity(a))
            .toList();
  test(
    'exit keeps pending identity, no credit, and confirms only once',
    () async {
      final d = FakeDevice();
      final c = companion(d);
      await c.breakNow();
      final id = c.session.id;
      await c.leaveBreak();
      expect(c.session.phase, Phase.pending);
      expect(c.session.id, id);
      expect(c.history, isEmpty);
      await c.complete();
      await c.complete();
      expect(c.history.length, 1);
      expect(c.history.single['id'], id);
      c.dispose();
    },
  );
  test('skip pending does not award progress', () async {
    final c = companion(FakeDevice());
    await c.breakNow();
    await c.leaveBreak();
    await c.cancel();
    expect(c.history, isEmpty);
    expect(c.session.phase, Phase.idle);
    c.dispose();
  });
  test(
    'routine association survives pause, activity changes and confirmation',
    () async {
      final d = FakeDevice()
        ..value = {
          'session': const Session(
            id: 'x',
            routineId: 'movement',
            phase: Phase.due,
          ).toJson(),
        };
      final c = companion(d);
      await c.breakNow();
      expect(c.session.routineId, 'movement');
      await c.pause();
      await c.resume();
      await c.switchActivity('quiet.soft');
      await c.leaveBreak();
      await c.complete();
      expect(c.history.single['routine'], 'movement');
      c.dispose();
    },
  );
  test(
    'routine edits preserve other routines and active presentation state',
    () async {
      final d = FakeDevice()
        ..value = {
          'routineState': {
            'short': {'phase': 'presented'},
          },
          'session': const Session(
            id: 'x',
            routineId: 'short',
            phase: Phase.rest,
          ).toJson(),
        };
      final c = companion(d);
      await c.saveRoutine({
        'id': 'short',
        'name': 'Rest',
        'breakSeconds': 30,
        'categories': ['quiet'],
        'selection': 'rotation',
      });
      expect(c.profiles.length, 3);
      expect(c.data['routineState']['short']['phase'], 'presented');
      c.dispose();
    },
  );
  test('pending state persists without reconciling into automatic credit', () {
    final s = Session.fromJson(
      const Session(id: 'x', routineId: 'short', phase: Phase.pending).toJson(),
    );
    expect(
      s.reconcile(const Moment(999999999, 999999999, 2)).phase,
      Phase.pending,
    );
    expect(s.routineId, 'short');
  });
  test(
    'failed exit persistence does not clear the stored active break',
    () async {
      final d = FakeDevice();
      final c = companion(d);
      await c.breakNow();
      d.fail = true;
      await c.leaveBreak();
      expect(c.error, contains('disk full'));
      expect(d.value['session']['phase'], 'rest');
      expect(c.history, isEmpty);
      c.dispose();
    },
  );
}
