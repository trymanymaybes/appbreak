// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class RecordingDevice extends FakeDevice {
  final calls = <String>[];
  bool denyMicrophone = false;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    calls.add(method);
    if (method == 'record' && denyMicrophone) {
      throw PlatformException(code: 'permission', message: 'Microphone permission requested. Tap Record again after granting it.');
    }
    if (method == 'stopRecord') {
      value['ideas'] = [{'id': 'voice', 'title': 'Voice idea', 'recording': 'voice.m4a'}];
      return 'voice.m4a' as T;
    }
    return null;
  }
}

void main() {
  testWidgets('popup mic stays reachable and records without leaving the break', (tester) async {
    final session = const Session(id: 'same-break', activity: 'quiet.soft')
        .at(Phase.rest, 60000, const Moment(100000, 1000, 1));
    final d = RecordingDevice()..value = {'session': session.toJson()};
    final c = ReadyCompanion(d);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: Home(controller: c, popup: true)));
    await tester.pumpAndSettle();
    for (final size in [const Size(320, 640), const Size(640, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('tab-0')), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Record a voice idea').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    d.calls.clear();
    await tester.tap(find.byTooltip('Record a voice idea'));
    await tester.pumpAndSettle();
    expect(d.calls, ['stopSpeech', 'record']);
    expect(find.byTooltip('Stop and save idea').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Stop and save idea'));
    await tester.pumpAndSettle();
    expect(d.calls, contains('stopRecord'));
    expect(c.ideas.single['recording'], 'voice.m4a');
    expect(find.byTooltip('Record a voice idea'), findsOneWidget);
    expect(c.session.id, session.id);
    expect(c.session.elapsedDue, session.elapsedDue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permission failure leaves mic ready for a retry', (tester) async {
    final d = RecordingDevice()..denyMicrophone = true;
    d.value = {'session': const Session(id: 'one', activity: 'quiet.soft')
        .at(Phase.rest, 60000, const Moment(100000, 1000, 1)).toJson()};
    final c = ReadyCompanion(d);
    await tester.pumpWidget(MaterialApp(home: Home(controller: c, popup: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Record a voice idea'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Stop and save idea'), findsNothing);
    expect(find.byTooltip('Record a voice idea'), findsOneWidget);
    d.denyMicrophone = false;
    await tester.tap(find.byTooltip('Record a voice idea'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Stop and save idea'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
