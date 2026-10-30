// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/services/read_aloud.dart';
import 'package:appbreak/application/controller.dart';
import 'package:appbreak/domain/activity.dart';
import 'package:appbreak/domain/session.dart';
import 'package:appbreak/platform/device.dart';

class Headers extends Fake implements HttpHeaders {
  @override
  final ContentType? contentType;
  final String? redirect;
  Headers(String mime, [this.redirect]) : contentType = ContentType.parse(mime);
  @override
  String? value(String name) => redirect;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  @override
  final Headers headers;
  final List<int> body;
  Response(
    String text, {
    this.statusCode = 200,
    String mime = 'text/html',
    String? redirect,
  }) : body = utf8.encode(text),
       headers = Headers(mime, redirect);
  @override
  int get contentLength => body.length;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request extends Fake implements HttpClientRequest {
  final Response response;
  Request(this.response);
  @override
  final HttpHeaders headers = Headers('text/html');
  @override
  set followRedirects(bool value) {}
  @override
  Future<HttpClientResponse> close() async => response;
}

class Client extends Fake implements HttpClient {
  final List<Response> responses;
  final urls = <Uri>[];
  bool closed = false;
  Client(this.responses);
  @override
  set connectionTimeout(Duration? value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    return Request(responses.removeAt(0));
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

class SpeechDevice extends Device {
  Map<String, dynamic>? spoken;
  @override
  Future<T?> call<T>(String method, [Map<String, dynamic>? args]) async {
    if (method == 'speak') spoken = args;
    return null;
  }
}

void main() {
  test('extracts article blocks and language, omits navigation and scripts', () {
    final article = ReadAloudSource.extract(
      '<html lang="kn"><title>Title</title><nav>Menu</nav><article><h1>Heading</h1><p>Hello <b>world</b> &amp; friends.</p><blockquote><p>Quoted once.</p></blockquote><script>evil()</script><p hidden>Hidden</p></article><footer>Footer</footer></html>',
    );
    expect(article.language, 'kn');
    expect(article.title, 'Title');
    expect(article.text, 'Heading\n\nHello world & friends.\n\nQuoted once.');
  });
  test(
    'plain text and main/body fallbacks; empty and oversized text rejected',
    () {
      expect(ReadAloudSource.extract('hello', plainText: true).text, 'hello');
      expect(ReadAloudSource.extract('<main><p>Main</p></main>').text, 'Main');
      expect(ReadAloudSource.extract('<div>Body</div>').text, 'Body');
      expect(
        () => ReadAloudSource.extract('<script>only script</script>'),
        throwsFormatException,
      );
      expect(
        () => ReadAloudSource.extract('x' * 60001, plainText: true),
        throwsFormatException,
      );
    },
  );
  test('validates URLs and splits speech without breaking Unicode', () {
    for (final value in [
      'file:///a',
      'http://example.com',
      'https://user:secret@example.com',
      'https://example.com:8443',
      'not a url',
    ]) {
      expect(() => ReadAloudSource.validateUrl(value), throwsFormatException);
    }
    final text = '🌿ಕನ್ನಡ ' * 1000;
    final article = ReadAloudArticle('Title', text, 'kn');
    expect(article.steps.map((s) => s['text']).join(), text);
    expect(
      article.steps.every((s) => (s['text'] as String).length <= 1800),
      isTrue,
    );
  });
  test('follows relative HTTPS redirects and closes client', () async {
    final client = Client([
      Response('', statusCode: 302, redirect: '/article'),
      Response('<article><p>Hello</p></article>'),
    ]);
    expect(
      (await ReadAloudSource(
        clientFactory: () => client,
      ).load('https://example.com')).text,
      'Hello',
    );
    expect(client.urls.last.path, '/article');
    expect(client.closed, isTrue);
  });
  test(
    'rejects insecure redirect, failed status, binary and oversized response',
    () async {
      for (final response in [
        Response('', statusCode: 302, redirect: 'http://example.com'),
        Response('', statusCode: 403),
        Response('pdf', mime: 'application/pdf'),
        Response('x' * (ReadAloudSource.maxBytes + 1)),
      ]) {
        final client = Client([response]);
        await expectLater(
          ReadAloudSource(
            clientFactory: () => client,
          ).load('https://example.com'),
          throwsFormatException,
        );
        expect(client.closed, isTrue);
      }
    },
  );
  test('narration uses extracted article and respects quiet mode', () async {
    final device = SpeechDevice();
    final c = Companion(device);
    c.activities = [
      Activity({
        'schemaVersion': 1,
        'id': 'read-aloud.web',
        'title': 'Read aloud',
        'category': 'read-aloud',
        'estimatedSeconds': 60,
        'steps': [
          {'kind': 'instruction', 'text': 'Instructions'},
        ],
      }),
    ];
    c.session = const Session(
      id: 'session',
      activity: 'read-aloud.web',
      phase: Phase.rest,
    );
    c.data = {
      'settings': {'quiet': false},
    };
    await c.narrate();
    expect(c.error, contains('Load a page'));
    expect(device.spoken, isNull);
    c.readAloudArticle = const ReadAloudArticle(
      'Title',
      'Actual article',
      'kn',
    );
    await c.narrate();
    expect(device.spoken?['language'], 'kn');
    expect((device.spoken?['steps'] as List).single['text'], 'Actual article');
    device.spoken = null;
    c.data = {
      'settings': {'quiet': true},
    };
    await c.narrate();
    expect(device.spoken, isNull);
    c.dispose();
  });
}
