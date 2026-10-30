// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/progress.dart';

void main() {
  const now = Moment(100000, 50000, 1);
  test('clock changes do not alter a running elapsed session', () {
    final s = const Session(id: 'a').at(Phase.work, 60000, now);
    expect(s.remaining(const Moment(9999999, 60000, 1)), 50000);
    expect(s.reconcile(const Moment(110000, 110000, 1)).phase, Phase.due);
  });
  test('reboot uses persisted wall deadline', () {
    final s = const Session(id: 'a').at(Phase.work, 60000, now);
    expect(s.remaining(const Moment(130000, 1000, 2)), 30000);
  });
  test('temporary pause preserves duration and resumes once', () {
    final s = const Session(
      id: 'a',
    ).at(Phase.work, 60000, now).pause(const Moment(110000, 60000, 1), 10000);
    expect(s.remainingMs, 50000);
    final resumed = s.reconcile(const Moment(120000, 70000, 1));
    expect(resumed.phase, Phase.work);
    expect(resumed.remaining(const Moment(120000, 70000, 1)), 50000);
    expect(resumed.reconcile(const Moment(120000, 70000, 1)).phase, Phase.work);
  });
  test('idle cannot be paused', () {
    expect(() => const Session().pause(now, 1000), throwsStateError);
  });
  test('long inactivity discards overdue work instead of backlog', () {
    final s = const Session(id: 'a').at(Phase.work, 60000, now);
    expect(
      s.reconcile(const Moment(999999999, 999999999, 2)).phase,
      Phase.idle,
    );
  });
  test('rest deadline is finished, never an automatic verified completion', () {
    final s = const Session(id: 'a').at(Phase.rest, 20000, now);
    expect(s.reconcile(const Moment(120000, 70000, 1)).phase, Phase.finished);
  });
  test('session JSON round trip retains state', () {
    final s = const Session(
      id: 'a',
    ).at(Phase.rest, 20000, now, activityId: 'quiet.soft');
    expect(
      Session.fromJson(jsonDecode(jsonEncode(s.toJson()))).toJson(),
      s.toJson(),
    );
  });
  final all =
      (jsonDecode(
                File('assets/activities.json').readAsStringSync(),
              )['activities']
              as List)
          .map((a) => Activity(a))
          .toList();
  test('eighteen bundled activities cover all required categories', () {
    expect(all.length, 19);
    expect(all.map((a) => a.category).toSet(), categories.toSet());
  });
  test('selection fits duration and avoids immediate repeat', () {
    final a = chooseActivity(all, {'quiet'}, 60, 'quiet.soft');
    expect(a.seconds, lessThanOrEqualTo(60));
    expect(a.id, isNot('quiet.soft'));
  });
  test('no enabled activity falls back to quiet without extending time', () {
    expect(chooseActivity(all, {}, 20, null).id, 'quiet.soft');
  });
  test('duplicate session IDs cannot award twice', () {
    final h = {'id': 'one', 'date': '2026-10-18', 'category': 'quiet'};
    expect(badges([h, h])['first']!['count'], 1);
    expect(badges([h, h])['quiet20']!['count'], 1);
  });
  test('consistency counts distinct days, not number of sessions', () {
    final h = List.generate(
      10,
      (i) => {'id': '$i', 'date': '2026-10-18', 'category': 'quiet'},
    );
    expect(badges(h)['days7']!['count'], 1);
    expect(badges(h)['days7']!['earned'], null);
  });
  test('idea sharing excludes recording and metadata', () {
    expect(
      shareIdea({
        'text': 'selected',
        'recording': 'secret.m4a',
        'session': 'private',
        'date': 'secret',
      }),
      'selected',
    );
  });
  test('achievement sharing excludes dates and unrelated data', () {
    expect(
      shareBadge({
        'title': 'First break',
        'count': 1,
        'target': 1,
        'earned': 'private',
        'notes': 'private',
      }),
      'First break — 1/1',
    );
  });
  test(
    'selection cycles through every fitting activity instead of only the first two',
    () {
      String? last;
      final seen = <String>{};
      final count = all.where((a) => a.seconds <= 60).length;
      for (var i = 0; i < count; i++) {
        final a = chooseActivity(all, categories.toSet(), 60, last);
        seen.add(a.id);
        last = a.id;
      }
      expect(seen.length, count);
    },
  );
  test(
    'large same-boot wall clock jump does not abandon valid elapsed session',
    () {
      final s = const Session(id: 'a').at(Phase.work, 60000, now);
      expect(
        s.reconcile(const Moment(999999999999, 51000, 1)).phase,
        Phase.work,
      );
    },
  );
}
