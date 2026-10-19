import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class PermissionsDevice extends FakeDevice {
  final requests = <String>[];
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    requests.add(method);
    if (method == 'capabilities')
      return <String, dynamic>{
            'notifications': false,
            'overlay': false,
            'usage': false,
            'microphone': false,
            'dictation': false,
            'screenSupported': true,
          }
          as T;
    return null;
  }
}

void main() {
  testWidgets(
    'first launch shows skippable checklist without unsolicited permission prompts',
    (tester) async {
      final d = PermissionsDevice();
      final c = ReadyCompanion(d);
      await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Permission checklist'), findsOneWidget);
      expect(d.value['settings']['permissionSetupSeen'], true);
      expect(d.requests, isNot(contains('microphoneAccess')));
      expect(d.requests, isNot(contains('notifications')));
      await tester.ensureVisible(find.text('Request notifications'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request notifications'));
      await tester.pumpAndSettle();
      expect(d.requests, contains('notifications'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Permission checklist'), findsNothing);
      await tester.tap(find.byTooltip('Permissions & setup'));
      await tester.pumpAndSettle();
      expect(find.text('Permission checklist'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('returning users keep dashboard and can open setup directly', (
    tester,
  ) async {
    final d = PermissionsDevice();
    d.value['settings'] = {'permissionSetupSeen': true};
    final c = ReadyCompanion(d);
    await tester.pumpWidget(MaterialApp(home: Home(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Permission checklist'), findsNothing);
    await tester.tap(find.byTooltip('Permissions & setup'));
    await tester.pumpAndSettle();
    expect(find.text('Permission checklist'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Allow microphone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();
    expect(d.requests, contains('microphoneAccess'));
    await tester.pumpWidget(const SizedBox());
  });
}
