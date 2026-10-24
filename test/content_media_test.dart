import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/ui/content_media.dart';
import 'controller_test.dart';

class SpeechDevice extends FakeDevice {
  Map<String, dynamic>? spoken;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'speak') spoken = args;
    return null;
  }
}

void main() {
  final data = Map<String, dynamic>.from(
    jsonDecode(
      File('activity-catalog/v1/catalog.json').readAsStringSync(),
    )['activities'][0],
  );
  final a = Activity({
    ...data,
    'media': [
      {
        'url': 'https://example.org/starter.png',
        'alt': 'A blue circle beside a short line',
        'fallbackText':
            'Imagine a circle and line. Invent a scene containing both.',
      },
    ],
  });
  testWidgets(
    'network image failure preserves descriptive and usable alternatives',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ContentMedia(activity: a)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A blue circle beside a short line'), findsOneWidget);
      expect(find.textContaining('Image unavailable.'), findsOneWidget);
      expect(
        find.text('Imagine a circle and line. Invent a scene containing both.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'narration includes media alternative and preserves selected activity identity',
    () async {
      final d = SpeechDevice();
      final c = Companion(d)
        ..activities = [a]
        ..data = {
          'settings': {'quiet': false},
        }
        ..session = Session(activity: a.id);
      await c.narrate();
      expect(
        (d.spoken!['steps'] as List).first['text'],
        contains('A blue circle'),
      );
      expect(
        (d.spoken!['steps'] as List).first['text'],
        contains('Invent a scene'),
      );
      expect(c.current!.id, a.id);
      c.dispose();
    },
  );
}
