// SPDX-License-Identifier: Apache-2.0
/// Version 1 evaluates stable session IDs. Imported duplicates never add credit.
Map<String, Map<String, dynamic>> badges(List<dynamic> history) {
  final unique = <String, Map<String, dynamic>>{};
  for (final raw in history) {
    final h = Map<String, dynamic>.from(raw);
    unique.putIfAbsent(h['id'], () => h);
  }
  final sessions = unique.values.toList()
    ..sort((a, b) => (a['date'] as String).compareTo(b['date']));
  final result = <String, Map<String, dynamic>>{};
  void evaluate(
    String id,
    String title,
    int target,
    bool Function(Map<String, dynamic>) accepts, {
    bool days = false,
  }) {
    final matching = sessions.where(accepts).toList();
    final dates = <String>{};
    final credited = days
        ? matching.where((s) => dates.add(s['date'])).toList()
        : matching;
    result[id] = {
      'title': title,
      'count': credited.length,
      'target': target,
      'earned': credited.length >= target ? credited[target - 1]['date'] : null,
      'rulesVersion': 1,
    };
  }

  evaluate('first', 'First break', 1, (_) => true);
  evaluate(
    'quiet20',
    'Twenty quiet breaks',
    20,
    (s) => s['category'] == 'quiet',
  );
  evaluate(
    'movement10',
    'Ten gentle movement breaks',
    10,
    (s) => s['category'] == 'movement',
  );
  evaluate('days7', 'Participation on seven days', 7, (_) => true, days: true);
  final explored = <String>{};
  final exploration = sessions
      .where((s) => s['category'] != 'unknown' && explored.add(s['category']))
      .toList();
  result['explore'] = {
    'title': 'Explore all six categories',
    'count': explored.length,
    'target': 6,
    'earned': exploration.length >= 6 ? exploration[5]['date'] : null,
    'rulesVersion': 1,
  };
  return result;
}

String shareIdea(Map<String, dynamic> idea) => idea['text'] as String;
String shareBadge(Map<String, dynamic> badge) =>
    '${badge['title']} — ${badge['count']}/${badge['target']}';
