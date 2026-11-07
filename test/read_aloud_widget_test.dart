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

class PlaybackDevice extends FakeDevice {
  String playback = 'playing';
  final actions = <String>[];
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'readAloudState') return {'state': playback} as T;
    if (method == 'readAloudControl') {
      final action = args!['action'] as String;
      actions.add(action);
      playback = action == 'pause' ? 'paused' : 'playing';
    }
    if (method == 'stopSpeech') { actions.add('stop'); playback = 'stopped'; }
    return null;
  }
}

void main() {
  testWidgets('controls reflect native playback and resume without restarting', (tester) async {
    final d = PlaybackDevice();
    final c = Companion(d);
    c.data['settings'] = {'quiet': false};
    c.readAloudArticle = const ReadAloudArticle('Title', 'Body', 'en-IN');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ReadAloudView(controller: c)))));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(d.actions, ['pause', 'resume']);
    expect(find.text('Pause'), findsOneWidget);
    // Notification / headset state changes are reflected on the next refresh.
    d.playback = 'paused';
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(d.actions, ['pause', 'resume', 'restart', 'stop']);
    expect(find.text('Play page'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('active playback controls survive a recreated view without article text', (tester) async {
    final d = PlaybackDevice();
    final c = Companion(d);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ReadAloudView(controller: c)))));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(d.actions, ['stop']);
    expect(find.text('Pause'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
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
