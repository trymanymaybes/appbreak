import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/session.dart';
import 'controller_test.dart' show FakeDevice;

class CatalogDevice extends FakeDevice {
  int requests = 0;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'catalogRefresh') requests++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pack = jsonDecode(
    File('activity-catalog/catalog.json').readAsStringSync(),
  );
  test(
    'cached community content survives offline without replacing local IDs',
    () async {
      final d = CatalogDevice();
      final c = Companion(d);
      final a = Activity(Map<String, dynamic>.from(pack['activities'][0]));
      c.catalog = [a];
      await c.refresh();
      expect(c.activities.single.id, a.id);
      d.value['customActivities'] = [
        {...a.data, 'title': 'Private version'},
      ];
      await c.refresh();
      expect(c.activities.single.title, 'Private version');
      expect(d.requests, 0);
      c.dispose();
    },
  );
  test('breaks never initiate catalogue refresh', () async {
    final d = CatalogDevice();
    final c = Companion(d);
    c.session = const Session().at(
      Phase.rest,
      60000,
      const Moment(100000, 1000, 1),
    );
    await c.refreshCatalog(manual: true);
    expect(d.requests, 0);
    c.dispose();
  });
  test('ongoing break keeps its instructions when catalogue changes', () async {
    final d = CatalogDevice();
    final c = Companion(d);
    final a = Activity(Map<String, dynamic>.from(pack['activities'][0]));
    c.activities = [a];
    c.catalog = [
      Activity({...a.data, 'title': 'Changed remotely'}),
    ];
    c.session = const Session().at(
      Phase.rest,
      60000,
      const Moment(100000, 1000, 1),
      activityId: a.id,
    );
    d.value['session'] = c.session.toJson();
    await c.refresh();
    expect(c.current?.title, a.title);
    c.dispose();
  });
}
