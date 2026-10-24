// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html;
import '../domain/many_maybes.dart';

/// Read-only public site access. Pages are parsed as data, never executed.
class ManyMaybesSite {
  final Future<String> Function(Uri)? read;
  ManyMaybesSite({this.read});
  static Uri trusted(String path) {
    final uri = Uri.parse(manyMaybesOrigin).resolve(path);
    if (uri.scheme != 'https' ||
        uri.host != 'trymanymaybes.github.io' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Unsupported challenge URL');
    }
    return uri;
  }

  Future<String> fetch(Uri uri) async {
    if (read != null) return read!(uri);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200)
        throw const HttpException('Challenge unavailable');
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024)
          throw const FormatException('Page too large');
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<String>> index() async {
    // Discover all linked challenges; no fixed six-challenge list or eager page downloads.
    final page = html.parse(await fetch(trusted('/challenges.html')));
    final numbers = <String>{};
    for (final a in page.querySelectorAll('a[href]')) {
      try {
        final uri = trusted(a.attributes['href']!);
        final match = RegExp(
          r'^/challenge-(\d{1,8})\.html$',
        ).firstMatch(uri.path);
        if (match != null) numbers.add(match.group(1)!);
      } on FormatException {
        /* Ignore links outside the challenge catalogue. */
      }
    }
    if (numbers.isEmpty) throw const FormatException('No challenges found');
    return numbers.toList();
  }

  Future<ManyMaybesChallenge> challenge(String number) async {
    if (!isChallengeNumber(number))
      throw const FormatException('Invalid challenge');
    final page = html.parse(await fetch(trusted('/challenge-$number.html')));
    final image =
        page.querySelector('main .starter-art img') ??
        page.querySelector('main img');
    var imageUrl = image?.attributes['src'] ?? '';
    // Prefer the site's linked PNG equivalent, without guessing an asset URL.
    if (imageUrl.endsWith('.svg')) {
      final pngPath = trusted(
        imageUrl,
      ).path.replaceFirst(RegExp(r'\.svg$'), '.png');
      for (final link in page.querySelectorAll('a[href]')) {
        try {
          final uri = trusted(link.attributes['href']!);
          if (uri.path == pngPath) {
            imageUrl = uri.toString();
            break;
          }
        } on FormatException {
          /* External links are not image candidates. */
        }
      }
    }
    if (imageUrl.isNotEmpty) imageUrl = trusted(imageUrl).toString();
    final description =
        page
            .querySelector('meta[name="description"]')
            ?.attributes['content']
            ?.trim() ??
        '';
    final alt = image?.attributes['alt']?.trim() ?? '';
    if (description.isEmpty && alt.isEmpty)
      throw const FormatException('Challenge has no readable description');
    if (description.length > 700 || alt.length > 700) {
      throw const FormatException('Challenge description is too long');
    }
    final title =
        page.querySelector('h1')?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ??
        'Challenge $number';
    if (title.length > 1500)
      throw const FormatException('Challenge title too long');
    return ManyMaybesChallenge(
      number: number,
      title: title,
      description: description,
      alt: alt,
      imageUrl: imageUrl,
    );
  }
}
