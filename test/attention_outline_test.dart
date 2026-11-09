import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/attention_outline.dart';

void main() {
  Widget view({bool reduceMotion = false, bool active = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: AttentionOutline(
          active: active,
          child: const SizedBox(width: 48, height: 48),
        ),
      ),
    ),
  );
  Border border(WidgetTester tester) =>
      (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(AttentionOutline),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .border!
          as Border;

  testWidgets(
    'idle never pulses; stopping mid-pulse clears animation immediately',
    (tester) async {
      await tester.pumpWidget(view());
      final initial = border(tester);
      expect(initial.top.color.a, 0);
      await tester.pump(const Duration(milliseconds: 450));
      expect(border(tester), initial);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(view(active: true));
      final active = border(tester);
      await tester.pump(const Duration(milliseconds: 450));
      expect(border(tester), isNot(active));
      expect(tester.getSize(find.byType(AttentionOutline)), const Size(48, 48));
      await tester.pumpWidget(view());
      expect(border(tester).top.color.a, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(view(active: true));
      await tester.pumpAndSettle();
      expect(border(tester).top.color.a, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion is steady only while active', (tester) async {
    await tester.pumpWidget(view(reduceMotion: true, active: true));
    final active = border(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(border(tester), active);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(view(reduceMotion: true));
    expect(border(tester).top.color.a, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
