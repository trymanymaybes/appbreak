// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/attention_outline.dart';
import 'controller_test.dart' show FakeDevice;

class SpeechDevice extends FakeDevice {
  bool speaking = false;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async =>
      method == 'speechActive' ? speaking as T : null;
}

void main() {
  Widget view({bool reduceMotion = false, bool active = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(child: AttentionOutline(active: active, child: const SizedBox(width: 48, height: 48))),
    ),
  );
  BoxDecoration decoration(WidgetTester tester) => tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(AttentionOutline), matching: find.byType(DecoratedBox)),
  ).decoration as BoxDecoration;

  testWidgets('idle stays still; active pulses continuously; stopping settles immediately', (tester) async {
    await tester.pumpWidget(view());
    final idle = decoration(tester).border;
    await tester.pump(const Duration(seconds: 2));
    expect(decoration(tester).border, idle);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(view(active: true));
    final start = decoration(tester).border;
    await tester.pump(const Duration(milliseconds: 450));
    expect(decoration(tester).border, isNot(start));
    await tester.pump(const Duration(seconds: 8));
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(tester.getSize(find.byType(AttentionOutline)), const Size(48, 48));
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    expect(decoration(tester).border, idle);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('toolbar follows actual speech state, including external stop', (tester) async {
    final device = SpeechDevice();
    await tester.pumpWidget(MaterialApp(home: SpeechOutline(device: device, child: const SizedBox(width: 48, height: 48))));
    await tester.pump();
    expect(tester.widget<AttentionOutline>(find.byType(AttentionOutline)).active, isFalse);
    device.speaking = true;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(tester.widget<AttentionOutline>(find.byType(AttentionOutline)).active, isTrue);
    device.speaking = false;
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.widget<AttentionOutline>(find.byType(AttentionOutline)).active, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps a steady visible outline', (tester) async {
    await tester.pumpWidget(view(reduceMotion: true, active: true));
    final initial = decoration(tester).border;
    await tester.pump(const Duration(seconds: 2));
    expect(decoration(tester).border, initial);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
