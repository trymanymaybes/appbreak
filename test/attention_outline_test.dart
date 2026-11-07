// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/attention_outline.dart';

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

  testWidgets('outline pulses, settles and preserves button bounds', (tester) async {
    await tester.pumpWidget(view());
    final initial = decoration(tester).border;
    await tester.pump(const Duration(milliseconds: 450));
    expect(decoration(tester).border, isNot(initial));
    expect(tester.getSize(find.byType(AttentionOutline)), const Size(48, 48));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(view(active: true));
    expect((decoration(tester).border! as Border).top.width, 2.5);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps a steady visible outline', (tester) async {
    await tester.pumpWidget(view(reduceMotion: true));
    final initial = decoration(tester).border;
    await tester.pump(const Duration(seconds: 2));
    expect(decoration(tester).border, initial);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
