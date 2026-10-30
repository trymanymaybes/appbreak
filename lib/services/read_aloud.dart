// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html;

class ReadAloudArticle {
  final String title, text, language;
  const ReadAloudArticle(this.title, this.text, this.language);

  // Keep each utterance below Android's TTS input limit, including Unicode.
  List<Map<String, dynamic>> get steps {
    final points = text.runes.toList();
    return [
      for (var i = 0; i < points.length; i += 900)
        {
          'kind': 'narration',
          'text': String.fromCharCodes(points.skip(i).take(900)),
        },
    ];
  }
}

/// Fetches public page data only; never runs scripts or loads subresources.
class ReadAloudSource {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxCharacters = 60000;
  final HttpClient Function() clientFactory;
  ReadAloudSource({HttpClient Function()? clientFactory})
    : clientFactory = clientFactory ?? HttpClient.new;

  static Uri validateUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        value.length > 2000) {
      throw const FormatException('Enter a complete HTTPS page URL.');
    }
    return uri.removeFragment();
  }

  Future<ReadAloudArticle> load(String value) async {
    var uri = validateUrl(value);
    final client = clientFactory()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        for (var redirects = 0; redirects <= 5; redirects++) {
          final request = await client.getUrl(uri);
          request.followRedirects = false;
          request.headers.set(
            HttpHeaders.acceptHeader,
            'text/html, text/plain',
          );
          final response = await request.close();
          if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
            final location = response.headers.value(HttpHeaders.locationHeader);
            if (location == null || redirects == 5) {
              throw const FormatException(
                'Too many or invalid page redirects.',
              );
            }
            uri = validateUrl(uri.resolve(location).toString());
            // Cancels the redirect body instead of downloading unbounded data.
            await response.listen((_) {}).cancel();
            continue;
          }
          if (response.statusCode != 200) {
            throw const FormatException(
              'Page unavailable. Use a public page without a login.',
            );
          }
          final type = response.headers.contentType;
          if (![
            'text/html',
            'application/xhtml+xml',
            'text/plain',
          ].contains(type?.mimeType)) {
            throw const FormatException(
              'Use an HTML or plain-text page. PDFs and media are not supported.',
            );
          }
          if (response.contentLength > maxBytes) {
            throw const FormatException('Page is too large to read aloud.');
          }
          final bytes = <int>[];
          await for (final chunk in response) {
            if (bytes.length + chunk.length > maxBytes) {
              throw const FormatException('Page is too large to read aloud.');
            }
            bytes.addAll(chunk);
          }
          final charset = type?.charset ?? 'utf-8';
          final encoding = Encoding.getByName(charset);
          if (encoding == null) {
            throw const FormatException('Unsupported page text encoding.');
          }
          return extract(
            encoding.decode(bytes),
            plainText: type?.mimeType == 'text/plain',
          );
        }
        throw const FormatException('Page unavailable.');
      })().timeout(const Duration(seconds: 25));
    } finally {
      client.close(force: true);
    }
  }

  static ReadAloudArticle extract(String source, {bool plainText = false}) {
    var title = 'Web page';
    var language = 'en-IN';
    var text = source.trim();
    if (!plainText) {
      final page = html.parse(source);
      title = page.querySelector('title')?.text.trim() ?? title;
      final lang = page.documentElement?.attributes['lang'];
      if (lang != null &&
          RegExp(r'^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$').hasMatch(lang)) {
        language = lang;
      }
      for (final node in page.querySelectorAll(
        'script, style, noscript, nav, header, footer, aside, form, button, '
        'iframe, svg, template, [hidden], [aria-hidden="true"]',
      )) {
        node.remove();
      }
      final root =
          page.querySelector('article') ??
          page.querySelector('main') ??
          page.body;
      final blocks =
          root?.querySelectorAll(
            'h1, h2, h3, h4, h5, h6, p, li, blockquote, pre',
          ) ??
          [];
      text = blocks
          .where((node) {
            // Parent blocks already include text from their nested paragraphs/lists.
            var parent = node.parent;
            while (parent != null && parent != root) {
              if (blocks.contains(parent)) return false;
              parent = parent.parent;
            }
            return true;
          })
          .map((node) => node.text.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((value) => value.isNotEmpty)
          .join('\n\n');
      if (text.isEmpty)
        text = root?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    }
    if (text.isEmpty) {
      throw const FormatException(
        'No readable text found. The page may require JavaScript or a login.',
      );
    }
    if (text.length > maxCharacters) {
      throw const FormatException(
        'Article is too long. Choose a shorter page (up to 60,000 characters).',
      );
    }
    return ReadAloudArticle(title, text, language);
  }
}
