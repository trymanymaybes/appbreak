import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/ui/home.dart';
import 'package:appbreak/ui/day_planner.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class ActionDevice extends FakeDevice {
  final calls = <String>[];
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    calls.add(method);
    return null;
  }
}

Map<String, dynamic> seed() => {
  'session': const Session(
    id: 'one',
    activity: 'manymaybes.challenge-01',
  ).at(Phase.rest, 60000, const Moment(100000, 1000, 1)).toJson(),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final activities =
      (jsonDecode(
                File('assets/activities.json').readAsStringSync(),
              )['activities']
              as List)
          .map((a) => Activity(a))
          .toList();
  test('repeated skip counts once and snapshots imagination type', () async {
    final d = ActionDevice()..value = seed();
    final c = Companion(d)..activities = activities;
    await c.cancel();
    await c.cancel();
    expect(c.missedBreaks.length, 1);
    expect(c.missedBreaks.single['category'], 'imagination');
    expect(c.history, isEmpty);
    c.dispose();
  });
  test(
    'postpone closes popup, uses elapsed 5 minutes and does not skip',
    () async {
      final d = ActionDevice()..value = seed();
      final c = Companion(d)..activities = activities;
      await c.postpone();
      expect(c.session.phase, Phase.work);
      expect(c.session.timing, 'elapsed');
      expect(c.session.remaining(c.moment), 300000);
      expect(c.missedBreaks, isEmpty);
      expect(c.history, isEmpty);
      expect(d.calls, contains('closePopup'));
      c.dispose();
    },
  );
  test('editing an older idea preserves its challenge', () async {
    final d = ActionDevice()
      ..value = {
        ...seed(),
        'ideas': [
          {
            'id': 'n',
            'text': 'Old',
            'activity': 'manymaybes.challenge-03',
            'session': 'old',
          },
        ],
      };
    final c = Companion(d);
    await c.saveIdea('Updated', id: 'n');
    expect(c.ideas.single['activity'], 'manymaybes.challenge-03');
    c.dispose();
  });
  testWidgets('action row stays visible after scrolling and rotating popup', (
    tester,
  ) async {
    final d = ActionDevice()..value = seed();
    final c = ReadyCompanion(d);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Home(controller: c, popup: true),
      ),
    );
    await tester.pumpAndSettle();
    for (final size in [const Size(390, 700), const Size(700, 390)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('tab-0')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      for (final label in ['Complete', 'Skip', 'Postpone'])
        expect(find.text(label).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(c.session.id, 'one');
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('planner editor fits a narrow screen', (tester) async {
    final c = Companion(FakeDevice());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DayPlanner(controller: c)),
        ),
      ),
    );
    await tester.tap(find.text('Plan activity'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
