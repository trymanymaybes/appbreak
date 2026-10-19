import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/home.dart';
import 'controller_test.dart' show FakeDevice;
import 'widget_test.dart' show ReadyCompanion;

class ResizeDevice extends FakeDevice {
  final sizes = <bool>[];
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'resizeBreakPopup') {
      sizes.add(args!['expanded'] as bool);
      return args['expanded'] as T;
    }
    return null;
  }
}

void main() {
  testWidgets('popup rotates and expands without resetting the break', (
    tester,
  ) async {
    final d = ResizeDevice();
    final original = const Session(
      id: 'same-break',
      activity: 'quiet.soft',
    ).at(Phase.rest, 60000, const Moment(100000, 1000, 1));
    d.value = {'session': original.toJson()};
    final c = ReadyCompanion(d);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: Home(controller: c, popup: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand popup'));
    await tester.pumpAndSettle();
    expect(find.text('Compact popup'), findsOneWidget);
    for (final size in [
      const Size(700, 390),
      const Size(360, 600),
      const Size(600, 360),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.session.id, original.id);
      expect(c.session.elapsedDue, original.elapsedDue);
    }
    await tester.ensureVisible(find.text('Compact popup'));
    await tester.tap(find.text('Compact popup'));
    await tester.pumpAndSettle();
    expect(d.sizes, [true, false]);
    expect(c.session.elapsedDue, original.elapsedDue);
    await tester.pumpWidget(const SizedBox());
  });
}
