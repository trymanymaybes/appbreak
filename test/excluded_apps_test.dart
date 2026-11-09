import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/ui/excluded_apps.dart';
import 'controller_test.dart' show FakeDevice;

class AppDevice extends FakeDevice {
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'installedApps')
      return [
            {'package': 'com.example.maps', 'label': 'Maps'},
            {'package': 'com.example.reader', 'label': 'Reader'},
          ]
          as T;
    if (method == 'capabilities') return {'usage': false} as T;
    return null;
  }
}

void main() {
  testWidgets('search, select, persist, remove and handle failed saves', (
    tester,
  ) async {
    final d = AppDevice();
    final c = Companion(d);
    await tester.pumpWidget(MaterialApp(home: ExcludedAppsPage(controller: c)));
    await tester.pumpAndSettle();
    expect(find.text('Usage access needed'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'maps');
    await tester.pumpAndSettle();
    expect(find.text('Reader'), findsNothing);
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(d.value['settings']['excludedApps'], ['com.example.maps']);
    final reloaded = Companion(d);
    reloaded.data = await d.load();
    expect(reloaded.settings['excludedApps'], ['com.example.maps']);
    reloaded.dispose();
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(d.value['settings']['excludedApps'], isEmpty);
    d.fail = true;
    await tester.tap(find.text('Maps'));
    await tester.pumpAndSettle();
    expect(c.settings['excludedApps'], isEmpty);
    expect(
      find.text('Could not save excluded apps. Please retry.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
