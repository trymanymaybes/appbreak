// SPDX-License-Identifier: Apache-2.0
import 'activity.dart';

/// Completed records win over stale skipped/missed copies of the same session.
List<Map<String, dynamic>> breakRecords(
  List<dynamic> completed,
  List<dynamic> missed,
  List<Activity> activities,
) {
  final unique = <String, Map<String, dynamic>>{};
  for (final raw in [...missed, ...completed]) {
    final r = Map<String, dynamic>.from(raw);
    final id = r['id'] as String?;
    if (id == null || id.isEmpty) continue;
    final done = completed.any((h) => h['id'] == id);
    final a = activities.where((a) => a.id == r['activity']).firstOrNull;
    unique[id] = {
      ...r,
      'category': r['category'] ?? a?.category ?? 'unknown',
      'title': r['title'] ?? a?.title ?? 'Break',
      'status': done
          ? 'Completed'
          : r['reason'] == 'skipped'
          ? 'Skipped'
          : 'Missed',
    };
  }
  return unique.values.toList()
    ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
}

List<Map<String, dynamic>> inPeriod(
  List<Map<String, dynamic>> records,
  String period,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final from = period == 'Today'
      ? today
      : today.subtract(Duration(days: now.weekday - 1));
  return records.where((r) {
    if (period == 'All time') return true;
    final d = DateTime.tryParse('${r['date']}');
    return d != null &&
        !d.isBefore(from) &&
        d.isBefore(today.add(const Duration(days: 1)));
  }).toList();
}

Map<String, Map<String, int>> countByType(List<Map<String, dynamic>> records) {
  final result = {
    for (final type in [...categories, 'unknown'])
      type: {'Completed': 0, 'Skipped': 0, 'Missed': 0},
  };
  for (final r in records) {
    final counts = result[r['category']] ?? result['unknown']!;
    final status = r['status'];
    if (counts.containsKey(status)) counts[status] = counts[status]! + 1;
  }
  return result;
}
