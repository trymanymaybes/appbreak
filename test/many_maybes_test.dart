import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/many_maybes.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/services/many_maybes_site.dart';
import 'package:appbreak/ui/many_maybes.dart';
import 'controller_test.dart';

class ChallengeDevice extends FakeDevice {
  final calls = <String>[];
  Map<String, dynamic>? speech;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    calls.add(method);
    if (method == 'speak') speech = args;
    if (method == 'stopRecord') {
      // Simulate native recording finalization before the controller reloads data.
      value['ideas'] = [
        {'id': 'recorded', 'activity': value['session']['activity']},
      ];
    }
    return null;
  }
}

Future<Companion> companion(ChallengeDevice d) async {
  final pack = jsonDecode(
    File('assets/activities.json').readAsStringSync(),
  );
  final c = Companion(
    d,
  )..activities = (pack['activities'] as List).map((x) => Activity(x)).toList();
  c.bundled = [...c.activities];
  c.session = const Session(
    id: 'break',
    activity: 'manymaybes.challenge-01',
  ).at(Phase.rest, 60000, const Moment(100000, 1000, 1));
  c.moment = const Moment(100000, 1000, 1);
  d.value = {
    'session': c.session.toJson(),
    'settings': {'quiet': false, 'autoSetup': false, 'routinesVersion': 1},
  };
  c.data = d.value;
  return c;
}

const newChallenge = ManyMaybesChallenge(
  number: '107',
  title: 'New possibility',
  description: 'Imagine a new shape.',
  alt: 'A curved line',
  imageUrl: '',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'discovers many challenges without fetching their pages, ignores external links',
    () async {
      final requests = <Uri>[];
      final site = ManyMaybesSite(
        read: (uri) async {
          requests.add(uri);
          return '${List.generate(110, (i) => '<a href="challenge-${i + 1}.html">Try</a>').join()}<a href="https://other.test/challenge-999.html">Other</a><a href="challenge-1.html">Duplicate</a>';
        },
      );
      expect((await site.index()).length, 110);
      expect(requests.single.path, '/challenges.html');
    },
  );
  test(
    'reads actual image links, description, decoded alt text and SVG fallback',
    () async {
      final site = ManyMaybesSite(
        read: (_) async =>
            '<meta name="description" content="Imagine &amp; explore."><main><h1>A possibility</h1><img src="/art/new.svg" alt="Two &amp; three"><a href="/art/new.png">PNG</a></main>',
      );
      final challenge = await site.challenge('107');
      expect(challenge.imageUrl, '$manyMaybesOrigin/art/new.png');
      expect(
        challenge.spokenPrompt,
        contains('Two & three. Imagine & explore.'),
      );
      final altOnly = ManyMaybesSite(
        read: (_) async => '<main><img src="starter.svg" alt="A loop"></main>',
      );
      final fallback = await altOnly.challenge('200');
      expect(fallback.narration, 'A loop');
      expect(fallback.imageUrl, '$manyMaybesOrigin/starter.svg');
      expect(fallback.spokenPrompt, contains('imagine'));
    },
  );
  test('rejects unreadable pages and off-site images', () async {
    for (final page in [
      '<main></main>',
      '<meta name="description" content="Prompt"><main><img src="https://other.test/a.png"></main>',
    ]) {
      final site = ManyMaybesSite(read: (_) async => page);
      await expectLater(site.challenge('107'), throwsFormatException);
    }
    expect(
      () => ManyMaybesSite.trusted('http://trymanymaybes.github.io/a'),
      throwsFormatException,
    );
    expect(challengeFor('manymaybes.challenge-107'), '107');
    expect(challengeFor('manymaybes.challenge-abc'), isNull);
  });
  test(
    'navigation preserves deadline, stops capture first, narrates site content and credits selected challenge',
    () async {
      final d = ChallengeDevice();
      final c = await companion(d);
      final deadline = c.session.elapsedDue;
      await c.useChallenge(
        newChallenge,
        sessionId: 'break',
        previousActivity: 'manymaybes.challenge-01',
      );
      expect(c.current!.id, newChallenge.activityId);
      expect(c.session.elapsedDue, deadline);
      expect(c.history, isEmpty);
      expect(c.missedBreaks, isEmpty);
      expect(c.ideas.single['activity'], 'manymaybes.challenge-01');
      expect(d.calls.take(2), ['stopRecord', 'stopAudio']);
      await c.narrate();
      expect(
        (d.speech!['steps'] as List).first['text'],
        newChallenge.spokenPrompt,
      );
      await c.refresh();
      expect(c.current!.id, newChallenge.activityId);
      await c.complete();
      expect(c.history.single['activity'], newChallenge.activityId);
      expect(c.history.single['category'], 'imagination');
      c.dispose();
    },
  );
  test('stale load cannot change a newer break or disabled activity', () async {
    final d = ChallengeDevice();
    final c = await companion(d);
    await c.useChallenge(
      newChallenge,
      sessionId: 'older-break',
      previousActivity: c.session.activity!,
    );
    expect(c.session.activity, 'manymaybes.challenge-01');
    expect(d.value['manyMaybesActivities'], isNull);
    c.dispose();
  });
  testWidgets(
    'browse and jump through live index, with failure preserving active challenge',
    (tester) async {
      final d = ChallengeDevice();
      final c = await companion(d);
      final site = ManyMaybesSite(
        read: (uri) async {
          if (uri.path == '/challenges.html')
            return '<a href="challenge-01.html">One</a><a href="challenge-107.html">New</a><a href="challenge-108.html">Unavailable</a>';
          if (uri.path.endsWith('108.html')) throw Exception('offline');
          return '<meta name="description" content="Imagine this challenge."><main><h1>New idea</h1></main>';
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: c,
                builder: (_, _) =>
                    ManyMaybesChallengeView(controller: c, site: site),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Many Maybes · Challenge 01 · 1 of 3'), findsOneWidget);
      await tester.tap(find.text('Next challenge'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(c.session.activity, 'manymaybes.challenge-107');
      expect(find.text('Many Maybes · Challenge 107 · 2 of 3'), findsOneWidget);
      await tester.tap(find.text('Next challenge'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(c.session.activity, 'manymaybes.challenge-107');
      expect(
        find.textContaining('Could not load this challenge'),
        findsOneWidget,
      );
      expect(find.text('Jump to challenge'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
