// SPDX-License-Identifier: Apache-2.0
class Activity {
  final Map<String, dynamic> data;
  Activity(this.data) {
    if (data.containsKey('contentVersion') &&
        (data['contentVersion'] is! int || data['contentVersion'] < 1))
      throw const FormatException('Invalid content version');
    if (data.containsKey('reveal') &&
        (data['reveal'] != 'manual' || data['answer'] is! String))
      throw const FormatException('Unsupported reveal behaviour');
    if (data.containsKey('media')) {
      if (data['media'] is! List || data['media'].length > 4)
        throw const FormatException('Invalid media');
      for (final m in data['media']) {
        if (m is! Map ||
            m.length != 3 ||
            ['url', 'alt', 'fallbackText'].any(
              (k) =>
                  m[k] is! String ||
                  (m[k] as String).trim().isEmpty ||
                  m[k].length > 2000,
            ))
          throw const FormatException(
            'Media needs alt text and a text alternative',
          );
        final u = Uri.tryParse(m['url']);
        if (u == null ||
            u.scheme != 'https' ||
            u.host.isEmpty ||
            u.userInfo.isNotEmpty ||
            u.hasPort)
          throw const FormatException('Unsupported media URL');
      }
    }

    if (data['schemaVersion'] != 1 ||
        !RegExp(r'^[a-z0-9._-]{1,80}$').hasMatch(id) ||
        seconds < 20 ||
        seconds > 300 ||
        steps.isEmpty) {
      throw FormatException('Invalid activity');
    }
  }
  String get id => data['id'];
  String get title => data['title'];
  String get category => data['category'];
  int get seconds => data['estimatedSeconds'];
  List<Map<String, dynamic>> get steps =>
      (data['steps'] as List).cast<Map<String, dynamic>>();
  String get text =>
      steps.map((s) => s['text'] ?? '').where((s) => s != '').join('\n\n');
}

const categories = [
  'quiet',
  'movement',
  'breathing',
  'hydration',
  'quiz',
  'imagination',
];
Activity chooseActivity(
  List<Activity> all,
  Set<String> enabled,
  int seconds,
  String? last,
) {
  final fit = all
      .where((a) => enabled.contains(a.category) && a.seconds <= seconds)
      .toList();
  if (fit.isNotEmpty) {
    final previous = fit.indexWhere((a) => a.id == last);
    return fit[(previous + 1) % fit.length];
  }
  return all.firstWhere((a) => a.id == 'quiet.soft');
}
