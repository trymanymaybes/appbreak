// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/profile.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/application/controller.dart';
import 'controller_test.dart' show FakeDevice;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all =
      (jsonDecode(
                File('assets/activities.json').readAsStringSync(),
              )['activities']
              as List)
          .map((a) => Activity(a))
          .toList();
  test('profile filters disabled activities and insufficient time', () {
    final a = all.firstWhere((a) => a.category == 'movement');
    final p = {
      'categories': ['movement'],
      'disabledActivities': [a.id],
    };
    final fit = fittingActivities(all, p, 60);
    expect(
      fit.every(
        (x) => x.category == 'movement' && x.id != a.id && x.seconds <= 60,
      ),
      true,
    );
  });
  test('invalid or too-long favourite falls back without extending time', () {
    expect(
      selectForProfile(
        all,
        {'categories': [], 'selection': 'fixed', 'favourite': 'missing'},
        20,
        null,
      ).id,
      'quiet.soft',
    );
  });
  test('choose-at-start remains quiet until explicit selection', () {
    expect(
      selectForProfile(
        all,
        {
          'categories': ['quiz'],
          'selection': 'choose',
        },
        300,
        null,
      ).id,
      'quiet.soft',
    );
  });
  test('active screen counter does not use wall or elapsed deadlines', () {
    final s = Session(
      id: 's',
      timing: 'screen',
    ).at(Phase.work, 60000, const Moment(1, 1, 1));
    const later = Moment(900000, 900000, 1);
    expect(s.remaining(later), 60000);
    expect(s.reconcile(later).phase, Phase.work);
    final paused = s.pause(later, 1000);
    expect(paused.resume(later).remaining(later), 60000);
    expect(paused.resume(later).tracking['activeInterval'], 60000);
    expect(Session.fromJson(s.toJson()).timing, 'screen');
  });
  test(
    'activity switching preserves deadline and completion identity',
    () async {
      final d = FakeDevice();
      final c = Companion(d)..activities = all;
      await c.breakNow();
      final id = c.session.id;
      final due = c.session.elapsedDue;
      await c.switchActivity('quiet.soft');
      expect(c.session.id, id);
      expect(c.session.elapsedDue, due);
      await c.complete();
      await c.complete();
      expect(c.history.length, 1);
      c.dispose();
    },
  );
  test('screen mode cannot start without usage permission', () async {
    final d = FakeDevice();
    final c = Companion(d);
    await c.updateSettings({'timing': 'screen'});
    await c.start();
    expect(c.error, contains('Usage access'));
    expect(c.session.phase, Phase.idle);
    c.dispose();
  });
  test('changing selected timing does not reset an existing session', () async {
    final c = Companion(FakeDevice());
    await c.start();
    final before = c.session.toJson();
    await c.updateSettings({'timing': 'screen'});
    expect(c.session.toJson(), before);
    c.dispose();
  });
}
