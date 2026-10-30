import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/profile.dart';
import 'package:appbreak/application/controller.dart';
import 'controller_test.dart' show FakeDevice;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final all = (jsonDecode(File('assets/activities.json').readAsStringSync())['activities'] as List)
      .map((a) => Activity(Map<String, dynamic>.from(a))).toList();
  final profile = <String, dynamic>{'id': 'test', 'categories': categories, 'selection': 'shuffle'};
  test('shuffle presents every eligible activity once and avoids cycle-boundary repeats', () {
    final state = <String, dynamic>{};
    final random = Random(21);
    final fit = fittingActivities(all, profile, 300);
    String? last;
    for (var cycle = 0; cycle < 3; cycle++) {
      final seen = <String>{};
      for (var i = 0; i < fit.length; i++) {
        final a = selectForProfile(all, profile, 300, last, selectionState: state, random: random);
        expect(seen.add(a.id), isTrue);
        expect(a.id, isNot(last));
        last = a.id;
      }
      expect(seen, fit.map((a) => a.id).toSet());
    }
  });
  test('saved state resumes, new activities enter and disabled activities leave the pool', () {
    final state = <String, dynamic>{};
    final first = selectForProfile(all, profile, 300, null, selectionState: state, random: Random(1));
    final restored = Map<String, dynamic>.from(jsonDecode(jsonEncode(state)));
    final next = selectForProfile(all, profile, 300, null, selectionState: restored, random: Random(1));
    expect(next.id, isNot(first.id));
    final limited = {...profile, 'activityIds': [first.id, next.id], 'disabledActivities': [next.id]};
    expect(selectForProfile(all, limited, 300, null, selectionState: restored).id, first.id);
    expect(restored['seen'], [first.id]);
    expect(selectForProfile(all, {...profile, 'categories': []}, 300, null, selectionState: restored).id, 'quiet.soft');
  });
  test('manual choices count as presented and exclusion reasons explain every filter', () {
    final a = all.first;
    final state = <String, dynamic>{};
    notePresented(a, all, profile, 300, state);
    expect((state['seen'] as List).contains(a.id), isTrue);
    final p = {...profile, 'categories': [], 'activityIds': [], 'disabledActivities': [a.id]};
    expect(activityExclusions(a, p, 1).length, 4);
  });
  test('routine rotation is independent and persists across controller recreation', () async {
    final profiles = [
      for (final id in ['a', 'b'])
        {...profile, 'id': id, 'name': id, 'selection': 'rotation', 'breakSeconds': 300}
    ];
    final d = FakeDevice()..value = {'settings': {'profiles': profiles, 'profile': 'a'}};
    final c = Companion(d)..activities = all;
    await c.breakNow();
    final firstA = c.current!.id;
    await c.complete();
    await c.updateSettings({'profile': 'b'});
    await c.breakNow();
    expect(c.current!.id, firstA);
    await c.complete();
    c.dispose();
    final restored = Companion(d)..activities = all;
    await restored.updateSettings({'profile': 'a'});
    await restored.breakNow();
    expect(restored.current!.id, all[1].id);
    expect(d.value['activitySelection']['b']['last'], firstA);
    restored.dispose();
  });
  test('fixed and choose keep their behaviour', () {
    expect(selectForProfile(all, {...profile, 'selection': 'fixed', 'favourite': all.last.id}, 300, null).id, all.last.id);
    expect(selectForProfile(all, {...profile, 'selection': 'choose'}, 300, null).id, 'quiet.soft');
  });
}
