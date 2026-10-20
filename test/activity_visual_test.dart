import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/ui/activity_visual.dart';

void main() {
  testWidgets('offline GIF is optional and can be stopped', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ActivityVisual(category: 'movement'))));
    await tester.pumpAndSettle();
    expect((tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName, endsWith('movement.png'));
    await tester.tap(find.text('Play animation'));
    await tester.pump(const Duration(milliseconds: 100));
    expect((tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName, endsWith('movement.gif'));
    await tester.tap(find.text('Pause animation'));
    await tester.pumpAndSettle();
    expect(find.text('Play animation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reduced motion keeps a still illustration', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: true), child: Scaffold(body: ActivityVisual(category: 'hydration')))));
    await tester.pumpAndSettle();
    expect(find.text('Play animation'), findsNothing);
    expect((tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName, endsWith('water.png'));
  });
}
