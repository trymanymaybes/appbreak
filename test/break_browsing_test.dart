import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/profile.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/main.dart';
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
  test(
    'manual browsing exposes all eighteen while auto suggestions retain profile filters',
    () {
      expect(all.length, 18);
      expect(browsableActivities(all, defaultProfiles.first).length, 18);
      expect(
        fittingActivities(
          all,
          defaultProfiles.first,
          30,
        ).every((a) => a.category == 'quiet' && a.seconds <= 30),
        true,
      );
      expect(
        browsableActivities(all, {
          'disabledActivities': [all.last.id],
        }).length,
        17,
      );
    },
  );
  test('Next visits every activity without extending a short break', () async {
    final c = Companion(FakeDevice())..activities = all;
    await c.breakNow();
    final id = c.session.id;
    final deadline = c.session.elapsedDue;
    final seen = <String>{};
    for (var i = 0; i < all.length; i++) {
      await c.cycleActivity(1);
      expect(c.error, isNull);
      seen.add(c.session.activity!);
      expect(c.session.id, id);
      expect(c.session.elapsedDue, deadline);
    }
    expect(seen.length, 18);
    c.moment = Moment(
      c.moment.wall + 25000,
      c.moment.elapsed + 25000,
      c.moment.boot,
    );
    expect(c.alternatives.length, 18);
    c.dispose();
  });
  test('disabled activities stay excluded from explicit switching', () async {
    final c = Companion(FakeDevice())..activities = all;
    await c.breakNow();
    await c.updateProfile({
      'disabledActivities': [all.last.id],
    });
    await c.switchActivity(all.last.id);
    expect(c.error, contains('disabled'));
    expect(c.session.activity, isNot(all.last.id));
    c.dispose();
  });
  test(
    'popup is dark from first frame; active and pending main-page breaks are dark',
    () {
      expect(darkBreakSurface(true, const Session()), true);
      for (final phase in [Phase.rest, Phase.finished, Phase.pending]) {
        expect(darkBreakSurface(false, Session(phase: phase)), true);
      }
      expect(darkBreakSurface(false, const Session()), false);
      final theme = appTheme(Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      final foreground = theme.colorScheme.primary.computeLuminance();
      final background = theme.colorScheme.surface.computeLuminance();
      expect((foreground + .05) / (background + .05), greaterThan(4.5));
    },
  );
}
