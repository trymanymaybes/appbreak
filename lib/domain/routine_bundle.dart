import 'activity.dart';

/// Strict data-only format. No global settings, permission or enabled fields.
class RoutineBundle {
  final Map<String, dynamic> data;
  RoutineBundle(this.data) {
    void require(bool ok, String why) {
      if (!ok) throw FormatException(why);
    }

    const keys = {
      'schemaVersion',
      'id',
      'version',
      'title',
      'description',
      'author',
      'license',
      'workActivity',
      'minimumProtocol',
      'dependencies',
      'defaults',
      'customisable',
    };
    require(
      data.keys.toSet().containsAll(keys) && data.keys.every(keys.contains),
      'Invalid bundle fields',
    );
    require(
      data['schemaVersion'] == 1 && data['minimumProtocol'] == 1,
      'Unsupported bundle protocol; update AppBreak',
    );
    require(
      data['id'] is String &&
          RegExp(r'^[a-z0-9._-]{1,80}$').hasMatch(data['id']),
      'Invalid bundle ID',
    );
    require(
      data['version'] is int && data['version'] > 0,
      'Invalid bundle version',
    );
    for (final k in [
      'title',
      'description',
      'author',
      'license',
      'workActivity',
    ]) {
      require(
        data[k] is String &&
            (data[k] as String).trim().isNotEmpty &&
            data[k].length <= 2000,
        'Invalid $k',
      );
    }
    require(
      data['dependencies'] is List &&
          data['dependencies'].isNotEmpty &&
          data['dependencies'].length <= 30,
      'Invalid dependencies',
    );
    final ids = <String>{};
    for (final d in data['dependencies']) {
      require(
        d is Map &&
            d.length == 2 &&
            d['id'] is String &&
            RegExp(r'^[a-z0-9._-]{1,80}$').hasMatch(d['id']) &&
            ids.add(d['id']) &&
            d['minimumVersion'] is int &&
            d['minimumVersion'] > 0,
        'Invalid or duplicate dependency',
      );
    }
    require(
      data['customisable'] is List &&
          (data['customisable'] as List).toSet().length ==
              data['customisable'].length &&
          (data['customisable'] as List).every(settingKeys.contains),
      'Unsupported customisation',
    );
    validateSettings(Map<String, dynamic>.from(data['defaults']));
  }
  static const settingKeys = {
    'workSeconds',
    'breakSeconds',
    'trigger',
    'selection',
    'quiet',
    'repeat',
  };
  static void validateSettings(Map<String, dynamic> s, {bool allowLocalShuffle = false}) {
    if (s.length != settingKeys.length ||
        !s.keys.every(settingKeys.contains) ||
        s['workSeconds'] is! int ||
        s['workSeconds'] < 60 ||
        s['workSeconds'] > 14400 ||
        s['breakSeconds'] is! int ||
        s['breakSeconds'] < 20 ||
        s['breakSeconds'] > 300 ||
        !['manual', 'interval', 'screen'].contains(s['trigger']) ||
        !['rotation', 'fixed', 'choose', if (allowLocalShuffle) 'shuffle'].contains(s['selection']) ||
        s['quiet'] is! bool ||
        s['repeat'] is! bool) {
      throw const FormatException('Unsupported routine settings or timing');
    }
  }

  String get id => data['id'];
  int get version => data['version'];
  String get title => data['title'];
  List<String> get activityIds => (data['dependencies'] as List)
      .map<String>((d) => d['id'] as String)
      .toList();
  Map<String, dynamic> settings(Map<String, dynamic> overrides) {
    if (!overrides.keys.every(
      (k) => (data['customisable'] as List).contains(k),
    )) {
      throw const FormatException('This setting is not customisable');
    }
    final s = {...Map<String, dynamic>.from(data['defaults']), ...overrides};
    validateSettings(s);
    return s;
  }

  List<Activity> resolve(List<Activity> available, Map<String, dynamic> s) {
    final result = <Activity>[];
    for (final dep in data['dependencies']) {
      final matches = available.where((a) => a.id == dep['id']);
      if (matches.isEmpty)
        throw FormatException(
          'Missing activity: ${dep['id']}. Refresh activities and retry.',
        );
      final a = matches.first;
      if ((a.data['contentVersion'] ?? 1) < dep['minimumVersion'])
        throw FormatException('Activity update needed: ${a.id}');
      if (a.seconds > s['breakSeconds'])
        throw FormatException(
          'Break must be at least ${a.seconds} seconds for ${a.title}',
        );
      result.add(a);
    }
    return result;
  }
}
