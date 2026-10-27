import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/platform/desktop_content.dart';

class OfflineContent extends DesktopContent {
  OfflineContent(super.root);
  @override
  Future<Uint8List> download(String url, int maxBytes) async =>
      throw const SocketException('offline');
}

void main() {
  late Map<String, dynamic> pack;
  setUp(() {
    pack = jsonDecode(
      File('activity-catalog/v1/catalog.json').readAsStringSync(),
    );
  });
  test('published catalogue is compatible with desktop', () {
    expect(DesktopContent.validate(jsonEncode(pack)), isNotEmpty);
  });
  test('unsupported versions, step capabilities and duplicate IDs fail', () {
    pack['schemaVersion'] = 9;
    expect(
      () => DesktopContent.validate(jsonEncode(pack)),
      throwsFormatException,
    );
    pack['schemaVersion'] = 1;
    pack['activities'].add(pack['activities'].first);
    expect(
      () => DesktopContent.validate(jsonEncode(pack)),
      throwsFormatException,
    );
    pack['activities'].removeLast();
    pack['activities'][0]['steps'][0]['kind'] = 'execute';
    expect(
      () => DesktopContent.validate(jsonEncode(pack)),
      throwsFormatException,
    );
  });
  test(
    'missing visual alt text fails and nonvisual content needs no invented alt',
    () {
      expect(DesktopContent.validate(jsonEncode(pack)), isNotEmpty);
      pack['activities'][0]['media'] = [
        {
          'url': 'https://example.com/image.png',
          'alt': '',
          'fallbackText': 'Read instructions',
        },
      ];
      expect(
        () => DesktopContent.validate(jsonEncode(pack)),
        throwsFormatException,
      );
    },
  );
  test('non-HTTPS downloads fail before network access', () async {
    final content = DesktopContent(() async => Directory.systemTemp);
    await expectLater(
      content.download('http://example.com/file', 100),
      throwsFormatException,
    );
  });
  test(
    'failed refresh retains validated cache and informative image fallback',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'appbreak-content-test',
      );
      try {
        await File('${dir.path}/catalog.json').writeAsString(
          jsonEncode({
            'activities': pack['activities'],
            'enabled': true,
            'status': 'Saved',
          }),
        );
        final content = OfflineContent(() async => dir);
        final result = jsonDecode(
          await content.catalog('catalogRefresh', {'manual': true}),
        );
        expect(result['activities'], pack['activities']);
        expect(
          result['status'],
          contains('Existing activities remain available'),
        );
        expect(await content.image('https://example.com/image.png'), isNull);
        expect(
          jsonDecode(await content.catalog('catalogLoad', {}))['activities'],
          pack['activities'],
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
}
