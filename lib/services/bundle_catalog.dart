import 'dart:convert';
import 'dart:io';
import '../domain/routine_bundle.dart';

class BundleCatalog {
  static final uri = Uri.parse(
    'https://raw.githubusercontent.com/trymanymaybes/appbreak/main/routine-bundles/v1/catalog.json',
  );
  final Future<String> Function()? read;
  BundleCatalog({this.read});
  static List<RoutineBundle> parse(String body) {
    if (utf8.encode(body).length > 256 * 1024)
      throw const FormatException('Bundle catalogue too large');
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (final c in body.split('')) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == '{' || c == '[') {
        if (++depth > 8)
          throw const FormatException('Catalogue too deeply nested');
      } else if (c == '}' || c == ']') {
        depth--;
      }
    }
    final p = jsonDecode(body);
    if (p is! Map ||
        p.length != 2 ||
        p['schemaVersion'] != 1 ||
        p['bundles'] is! List ||
        p['bundles'].length > 100)
      throw const FormatException('Unsupported bundle catalogue');
    final ids = <String>{};
    return (p['bundles'] as List).map((b) {
      final bundle = RoutineBundle(Map<String, dynamic>.from(b));
      if (!ids.add(bundle.id))
        throw const FormatException('Duplicate bundle ID');
      return bundle;
    }).toList();
  }

  Future<String> fetch() async {
    if (read != null) {
      final body = await read!();
      parse(body);
      return body;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        final response = await request.close();
        if (response.statusCode != 200)
          throw const HttpException('Bundle catalogue unavailable');
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 256 * 1024)
            throw const FormatException('Bundle catalogue too large');
        }
        final body = utf8.decode(bytes);
        parse(body);
        return body;
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }
}
