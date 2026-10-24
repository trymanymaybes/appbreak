import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/routine_bundle.dart';
import 'package:appbreak/domain/profile.dart';
import 'package:appbreak/services/bundle_catalog.dart';
import 'package:appbreak/ui/routine_bundles.dart';
import 'controller_test.dart' show FakeDevice;

final raw = File('routine-bundles/v1/catalog.json').readAsStringSync();
List<Activity> activities(String path) =>
    (jsonDecode(File(path).readAsStringSync())['activities'] as List)
        .map((a) => Activity(a))
        .toList();
Companion setup(FakeDevice d) => Companion(d)
  ..bundled = activities('assets/activities.json')
  ..catalog = activities('activity-catalog/v1/catalog.json');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unsupported, malformed, duplicate and executable bundle fields reject',
    () {
      for (final body in ['{}', '{"schemaVersion":2,"bundles":[]}', '[' * 20]) {
        expect(() => BundleCatalog.parse(body), throwsFormatException);
      }
      final b = BundleCatalog.parse(raw).first;
      expect(
        () => RoutineBundle({...b.data, 'script': 'code'}),
        throwsFormatException,
      );
      expect(
        () => BundleCatalog.parse(
          jsonEncode({
            'schemaVersion': 1,
            'bundles': [b.data, b.data],
          }),
        ),
        throwsFormatException,
      );
      expect(() => b.settings({'enabled': true}), throwsFormatException);
      expect(() => b.resolve([], b.settings({})), throwsFormatException);
      final changed = RoutineBundle({
        ...b.data,
        'dependencies': [
          {'id': 'quiet.soft', 'minimumVersion': 2},
        ],
      });
      expect(
        () => changed.resolve(
          activities('assets/activities.json'),
          changed.settings({}),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'explicit atomic install pins dependencies, disables reminders and retains personal state',
    () async {
      final d = FakeDevice()
        ..value = {
          'history': [
            {'id': 'past'},
          ],
          'ideas': [
            {'id': 'note', 'text': 'Keep'},
          ],
          'settings': {'quiet': false},
        };
      final c = setup(d);
      final b = BundleCatalog.parse(raw)[1];
      await c.installBundle(b, {'workSeconds': 1800});
      expect(c.error, isNull);
      final p = c.profiles.last;
      expect(p['workSeconds'], 1800);
      expect(p['enabled'], false);
      expect(p['notifications'], false);
      expect(p['popup'], false);
      expect(c.settings['quiet'], false);
      expect(
        d.value['customActivities'].single['id'],
        'community.imagination.window',
      );
      expect(fittingActivities(c.activities, p, 60).map((a) => a.id), [
        'community.imagination.window',
      ]);
      await c.installBundle(b, {});
      expect(c.error, contains('Already installed'));
      expect(c.profiles.last['workSeconds'], 1800);
      await c.deleteRoutine(p['id']);
      expect(d.value['history'].single['id'], 'past');
      expect(d.value['ideas'].single['id'], 'note');
      expect(d.value['customActivities'], isNotEmpty);
      await c.installBundle(b, {});
      expect(c.profiles.last['id'], isNot(p['id']));
      c.dispose();
    },
  );
  test(
    'invalid dependencies and failed persistence never partially install',
    () async {
      final d = FakeDevice();
      final c = setup(d);
      final b = BundleCatalog.parse(raw)[2];
      await c.installBundle(b, {'breakSeconds': 20});
      expect(c.error, contains('at least'));
      expect(d.value['customActivities'], isNull);
      d.fail = true;
      await c.installBundle(b, {});
      expect(c.error, contains('disk full'));
      expect(d.value['settings'], isNull);
      c.dispose();
    },
  );
  test(
    'catalogue refresh preserves customised routines and offline cache on network failure',
    () async {
      final d = FakeDevice();
      final c = setup(d);
      await c.refreshBundles(source: BundleCatalog(read: () async => raw));
      await c.installBundle(c.routineBundles.first, {'workSeconds': 2100});
      final upgraded = jsonDecode(raw);
      upgraded['bundles'][0]['version'] = 2;
      await c.refreshBundles(
        source: BundleCatalog(read: () async => jsonEncode(upgraded)),
      );
      expect(c.profiles.last['workSeconds'], 2100);
      expect(c.profiles.last['bundleVersion'], 1);
      await c.refreshBundles(
        source: BundleCatalog(
          read: () async => throw const SocketException('offline'),
        ),
      );
      expect(c.routineBundles.first.version, 2);
      expect(c.bundleStatus, contains('Previously downloaded'));
      c.dispose();
    },
  );
  test(
    'legacy activity IDs remain unchanged and media requires real alternatives',
    () {
      final a = activities('activity-catalog/catalog.json').single;
      expect(a.data['contentVersion'], isNull);
      expect(a.id, 'community.imagination.window');
      for (final alt in ['', ' ']) {
        expect(
          () => Activity({
            ...a.data,
            'media': [
              {
                'url': 'https://example.org/a.png',
                'alt': alt,
                'fallbackText': 'Imagine a loop',
              },
            ],
          }),
          throwsFormatException,
        );
      }
      expect(
        () => Activity({...a.data, 'schemaVersion': 2}),
        throwsFormatException,
      );
    },
  );
  test(
    'explicit update preserves identity, settings, reminders and progress',
    () async {
      final d = FakeDevice();
      final c = setup(d);
      final b = BundleCatalog.parse(raw).first;
      await c.installBundle(b, {'workSeconds': 2100});
      final old = c.profiles.last;
      await c.saveRoutine({
        ...old,
        'name': 'My reading',
        'categories': ['quiet', 'hydration'],
        'enabled': true,
        'popup': true,
        'notifications': true,
        'message': 'My cue',
      });
      d.value['history'] = [
        {'id': 'past', 'routine': old['id']},
      ];
      final next = RoutineBundle({
        ...b.data,
        'version': 2,
        'defaults': {...b.data['defaults'], 'workSeconds': 3000},
      });
      await c.installBundle(next, {}, updateRoutineId: old['id']);
      expect(c.error, isNull);
      final updated = c.profiles.last;
      expect(updated['id'], old['id']);
      expect(updated['bundleVersion'], 2);
      expect(updated['workSeconds'], 2100);
      expect(updated['name'], 'My reading');
      expect(updated['categories'], ['quiet', 'hydration']);
      expect(updated['enabled'], true);
      expect(updated['popup'], true);
      expect(updated['message'], 'My cue');
      expect(d.value['history'].single['routine'], old['id']);
      await c.installBundle(b, {}, updateRoutineId: old['id']);
      expect(c.error, contains('already installed'));
      c.dispose();
    },
  );
  test(
    'update rejects unmet dependencies atomically and preserves local activity choices',
    () async {
      final d = FakeDevice();
      final c = setup(d);
      final b = BundleCatalog.parse(raw).first;
      await c.installBundle(b, {});
      final old = c.profiles.last;
      final bad = RoutineBundle({
        ...b.data,
        'version': 2,
        'dependencies': [
          {'id': 'missing', 'minimumVersion': 1},
        ],
      });
      await c.installBundle(bad, {}, updateRoutineId: old['id']);
      expect(c.error, contains('Missing activity'));
      expect(c.profiles.last['bundleVersion'], 1);
      final custom = {...old}..remove('activityIds');
      await c.saveRoutine(custom);
      final next = RoutineBundle({
        ...b.data,
        'version': 2,
        'dependencies': [
          {'id': 'quiet.distance', 'minimumVersion': 1},
        ],
      });
      await c.installBundle(next, {}, updateRoutineId: old['id']);
      expect(c.error, isNull);
      expect(c.profiles.last.containsKey('activityIds'), false);
      c.dispose();
    },
  );
  test(
    'untouched activity selection follows new bundle dependencies',
    () async {
      final d = FakeDevice();
      final c = setup(d);
      final b = BundleCatalog.parse(raw).first;
      await c.installBundle(b, {});
      final id = c.profiles.last['id'];
      final next = RoutineBundle({
        ...b.data,
        'version': 2,
        'dependencies': [
          {'id': 'quiet.distance', 'minimumVersion': 1},
        ],
      });
      await c.installBundle(next, {}, updateRoutineId: id);
      expect(c.error, isNull);
      expect(c.profiles.last['activityIds'], ['quiet.distance']);
      c.dispose();
    },
  );
  testWidgets(
    'preview shows dependencies, validates then adds disabled routine',
    (tester) async {
      final d = FakeDevice();
      final c = setup(d);
      await tester.pumpWidget(
        MaterialApp(
          home: BundlePreview(
            controller: c,
            bundle: BundleCatalog.parse(raw).first,
          ),
        ),
      );
      expect(find.textContaining('quiet.soft'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '1800');
      await tester.scrollUntilVisible(
        find.text('Add disabled routine'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add disabled routine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Added with reminders off'), findsOneWidget);
      expect(c.profiles.last['workSeconds'], 1800);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
