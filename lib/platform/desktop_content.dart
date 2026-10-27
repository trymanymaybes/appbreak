// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/activity.dart';

/// Bounded, data-only downloads. No redirects, scripts or private data uploads.
class DesktopContent {
  DesktopContent(this.root);
  final Future<Directory> Function() root;
  static const endpoint =
      'https://raw.githubusercontent.com/trymanymaybes/appbreak/main/activity-catalog/v1/catalog.json';
  Future<Uint8List> download(String url, int maxBytes) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      throw const FormatException('Unsupported content URL');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        final response = await request.close();
        if (response.statusCode != 200 || response.contentLength > maxBytes)
          throw const FormatException('Content unavailable or too large');
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (bytes.length + chunk.length > maxBytes)
            throw const FormatException('Content too large');
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> validate(
    String body, {
    bool community = true,
  }) {
    if (utf8.encode(body).length > 256 * 1024)
      throw const FormatException('Pack too large');
    var depth = 0;
    var quoted = false;
    var escape = false;
    for (final ch in body.runes) {
      if (quoted) {
        if (escape) {
          escape = false;
        } else if (ch == 92) {
          escape = true;
        } else if (ch == 34) {
          quoted = false;
        }
      } else if (ch == 34) {
        quoted = true;
      } else if (ch == 123 || ch == 91) {
        if (++depth > 8)
          throw const FormatException('Content nested too deeply');
      } else if (ch == 125 || ch == 93) {
        if (--depth < 0) throw const FormatException('Malformed content');
      }
    }
    if (depth != 0 || quoted) throw const FormatException('Malformed content');
    final pack = jsonDecode(body);
    if (pack is! Map ||
        pack['schemaVersion'] != 1 ||
        pack['activities'] is! List ||
        pack['activities'].isEmpty ||
        pack['activities'].length > 200)
      throw const FormatException('Unsupported activity pack');
    final ids = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final raw in pack['activities']) {
      final data = Map<String, dynamic>.from(raw as Map);
      for (final field in ['answer', 'reflectionQuestion', 'source']) {
        if (data.containsKey(field) &&
            (data[field] is! String ||
                data[field].trim().isEmpty ||
                data[field].length > 2000))
          throw FormatException('Invalid $field');
      }
      if (community && data['contentLicense'] != 'CC-BY-4.0')
        throw const FormatException('Unsupported community licence');
      final activity = Activity(data);
      if (!ids.add(activity.id) ||
          (community && !activity.id.startsWith('community.')))
        throw const FormatException('Duplicate or invalid activity identity');
      for (final field in [
        'title',
        'description',
        'language',
        'author',
        'attribution',
        'contentLicense',
      ]) {
        if (data[field] is! String ||
            (data[field] as String).trim().isEmpty ||
            data[field].length > 2000)
          throw FormatException('Missing or invalid $field');
      }
      if (!categories.contains(activity.category) ||
          data['requiresVisualAttention'] is! bool ||
          data['requiresInput'] is! bool ||
          data['accessibleAlternatives'] is! List ||
          data['accessibleAlternatives'].isEmpty ||
          data['accessibleAlternatives'].length > 20 ||
          data['accessibleAlternatives'].any(
            (v) => v is! String || v.trim().isEmpty || v.length > 2000,
          ))
        throw const FormatException('Missing accessibility information');
      if (activity.steps.length > 30)
        throw const FormatException('Too many steps');
      for (final step in activity.steps) {
        if (['thinking', 'silence'].contains(step['kind'])) {
          if (step['seconds'] is! int ||
              step['seconds'] < 1 ||
              step['seconds'] > 300)
            throw const FormatException('Invalid timing');
        } else if ([
          'instruction',
          'narration',
          'completion',
        ].contains(step['kind'])) {
          if (step['text'] is! String ||
              step['text'].trim().isEmpty ||
              step['text'].length > 2000)
            throw const FormatException('Invalid instruction');
        } else {
          throw const FormatException('Unsupported step capability');
        }
      }
      result.add(data);
    }
    return result;
  }

  Future<Map<String, dynamic>> cached() async {
    final f = File('${(await root()).path}/catalog.json');
    if (!await f.exists())
      return {
        'activities': [],
        'enabled': true,
        'status': 'Built-in activities ready.',
      };
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if ((data['activities'] as List).isNotEmpty)
        validate(
          jsonEncode({'schemaVersion': 1, 'activities': data['activities']}),
        );
      return data;
    } catch (_) {
      return {
        'activities': [],
        'enabled': false,
        'status': 'Cached catalogue invalid. Download again.',
      };
    }
  }

  Future<String> catalog(String method, Map<String, dynamic> args) async {
    final data = await cached();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (method == 'catalogEnabled') data['enabled'] = args['enabled'] == true;
    if (method == 'catalogRefresh' &&
        (data['enabled'] == true || args['download'] == true) &&
        now - (data['attempt'] as int? ?? 0) >=
            (args['manual'] == true ? 60000 : 86400000)) {
      data['attempt'] = now;
      try {
        final activities = validate(
          utf8.decode(await download(endpoint, 256 * 1024)),
        );
        data.addAll({
          'activities': activities,
          'status': 'Catalogue saved for offline use.',
          'lastSuccess': now,
        });
      } catch (_) {
        data['status'] =
            'Catalogue unavailable. Existing activities remain available; retry later.';
      }
    }
    if (method != 'catalogLoad') {
      final f = File('${(await root()).path}/catalog.json.next');
      await f.writeAsString(jsonEncode(data), flush: true);
      await f.rename('${(await root()).path}/catalog.json');
    }
    return jsonEncode(data);
  }

  Future<Uint8List?> image(String url) async {
    final directory = Directory('${(await root()).path}/images');
    await directory.create(recursive: true);
    final file = File('${directory.path}/${sha256.convert(utf8.encode(url))}');
    if (await file.exists()) return file.readAsBytes();
    try {
      final bytes = await download(url, 5 * 1024 * 1024);
      // Cache at most 40 MiB; images are optional and text is always retained.
      final files = await directory
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      var size = 0;
      for (final f in files) {
        size += await f.length();
      }
      for (final f in files) {
        if (size + bytes.length <= 40 * 1024 * 1024) break;
        size -= await f.length();
        await f.delete();
      }
      await file.writeAsBytes(bytes, flush: true);
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
