// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:appbreak/domain/activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/home.dart';
import 'package:appbreak/application/controller.dart';
import 'controller_test.dart' show FakeDevice;

class ReadyCompanion extends Companion {
  ReadyCompanion(super.device);
  @override
  Future<void> init() async {
    activities =
        (jsonDecode(
                  File('assets/activities.json').readAsStringSync(),
                )['activities']
                as List)
            .map((a) => Activity(a))
            .toList();
    bundled = [...activities];
    await refresh();
  }
}

void main() {
  testWidgets('dashboard remains usable at large text size', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = Companion(FakeDevice());
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Home(controller: c),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('Start work session'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('tab-0')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Start work session'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('break player fits large text and exposes activity switching', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = FakeDevice()
      ..value = {
        'session': {
          'id': 'break',
          'phase': 'rest',
          'wallDue': 400000,
          'elapsedDue': 301000,
          'boot': 1,
          'remainingMs': 0,
          'activity': 'quiet.soft',
          'resumePhase': 'work',
        },
      };
    final c = ReadyCompanion(d);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Home(controller: c),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Take a little space'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quiet break'),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('tab-0')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Quiet break'), findsOneWidget);
    expect(find.byTooltip('Next activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('routines and editor remain usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ReadyCompanion(FakeDevice());
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Home(controller: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Routines'));
    await tester.pumpAndSettle();
    expect(find.text('Task & lifestyle routines'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add routine'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add routine'));
    await tester.pumpAndSettle();
    expect(find.text('Routine name'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });
}
