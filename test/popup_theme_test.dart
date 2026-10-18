import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/main.dart';
import 'package:appbreak/platform/device.dart';
import 'package:appbreak/ui/home.dart';

void main() {
  testWidgets(
    'real popup app stays dark through session load and disposes cleanly',
    (tester) async {
      var data = <String, dynamic>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Device.channel, (call) async {
            if (call.method == 'load') return jsonEncode(data);
            if (call.method == 'save') {
              data = jsonDecode(call.arguments['json']);
              return null;
            }
            if (call.method == 'now')
              return {'wall': 100000, 'elapsed': 1000, 'boot': 1};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Device.channel, null),
      );
      await tester.pumpWidget(const AppBreak(popup: true));
      expect(
        Theme.of(tester.element(find.byType(Home))).brightness,
        Brightness.dark,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Home))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
