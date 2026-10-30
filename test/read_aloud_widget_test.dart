// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/services/read_aloud.dart';
import 'package:appbreak/ui/read_aloud.dart';
import 'controller_test.dart' show FakeDevice;

class Source extends ReadAloudSource {
  final Completer<ReadAloudArticle> result = Completer();
  @override
  Future<ReadAloudArticle> load(String value) => result.future;
}

void main() {
  testWidgets(
    'loads preview, saves URL and clears stale text when URL changes',
    (tester) async {
      final d = FakeDevice();
      final c = Companion(d);
      final source = Source();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadAloudView(controller: c, source: source),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/article',
      );
      await tester.tap(find.text('Load page'));
      await tester.pump();
      expect(find.text('Loading page…'), findsOneWidget);
      source.result.complete(
        const ReadAloudArticle('Article title', 'Article body', 'en-IN'),
      );
      await tester.pumpAndSettle();
      expect(c.readAloudArticle?.text, 'Article body');
      expect(
        d.value['settings']['readAloudUrl'],
        'https://example.com/article',
      );
      expect(find.text('Preview extracted text'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/other',
      );
      await tester.pump();
      expect(c.readAloudArticle, isNull);
      expect(find.text('Preview extracted text'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('late page result does not replace a changed URL', (
    tester,
  ) async {
    final c = Companion(FakeDevice());
    final source = Source();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadAloudView(controller: c, source: source),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'https://example.com/first');
    await tester.tap(find.text('Load page'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      'https://example.com/second',
    );
    source.result.complete(
      const ReadAloudArticle('Old', 'Stale content', 'en'),
    );
    await tester.pumpAndSettle();
    expect(c.readAloudArticle, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
