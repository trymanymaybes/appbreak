// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/platform/device.dart';
import 'package:appbreak/domain/session.dart';

class FakeDevice extends Device {
  Map<String, dynamic> value = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load() async => jsonDecode(jsonEncode(value));
  @override
  Future<Moment> now() async => const Moment(100000, 1000, 1);
  @override
  Future<void> save(Map<String, dynamic> data) async {
    if (fail) throw StateError('disk full');
    value = jsonDecode(jsonEncode(data));
  }

  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'persistence failure is surfaced without pretending idea saved',
    () async {
      final d = FakeDevice()..fail = true;
      final c = Companion(d);
      await c.saveIdea('test');
      expect(c.error, contains('disk full'));
      expect(d.value['ideas'], null);
      c.dispose();
    },
  );
  test('no overlapping work sessions', () async {
    final d = FakeDevice();
    final c = Companion(d);
    await c.start();
    await c.start();
    expect(c.error, contains('Cancel'));
    expect(d.value['session']['phase'], 'work');
    c.dispose();
  });
}
