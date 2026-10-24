// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../application/controller.dart';

class BreakHistory extends StatefulWidget {
  final Companion controller;
  const BreakHistory({super.key, required this.controller});
  @override
  State<BreakHistory> createState() => _BreakHistoryState();
}

class _BreakHistoryState extends State<BreakHistory> {
  String? category, activity;
  int limit = 50;
  String recordedTime(Map<String, dynamic> record) {
    final raw = record['recordedAt'];
    if (raw is! int) return '${record['date']} · Time not recorded';
    final offset = record['utcOffsetMinutes'];
    final time = offset is int
        ? DateTime.fromMillisecondsSinceEpoch(
            raw,
            isUtc: true,
          ).add(Duration(minutes: offset))
        : DateTime.fromMillisecondsSinceEpoch(raw);
    final local = MaterialLocalizations.of(context);
    return '${local.formatMediumDate(time)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(time), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final records = c.breakRecords;
    final types = records.map((r) => r['category'] as String).toSet().toList()
      ..sort();
    final selectedType = types.contains(category) ? category : null;
    final byType = records
        .where((r) => selectedType == null || r['category'] == selectedType)
        .toList();
    final names = <String, String>{};
    for (final r in byType) {
      final id = r['activity'] as String?;
      if (id != null && id.isNotEmpty)
        names.putIfAbsent(id, () => r['title'] as String);
    }
    final selectedActivity = names.containsKey(activity) ? activity : null;
    final matching = byType
        .where(
          (r) => selectedActivity == null || r['activity'] == selectedActivity,
        )
        .toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in matching.take(limit)) {
      groups.putIfAbsent('${r['date']}', () => []).add(r);
    }
    return ExpansionTile(
      key: const PageStorageKey('past-break-records'),
      title: Text('Past records (${records.length})'),
      subtitle: const Text(
        'Expand to filter activities and view recorded times',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('history-type-$selectedType'),
                initialValue: selectedType ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Activity type'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All activity types'),
                  ),
                  for (final type in types)
                    DropdownMenuItem(
                      value: type,
                      child: Text(
                        type == 'unknown'
                            ? 'Unclassified'
                            : type[0].toUpperCase() + type.substring(1),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  category = value == '' ? null : value;
                  activity = null;
                  limit = 50;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'history-activity-$selectedType-$selectedActivity',
                ),
                initialValue: selectedActivity ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Activity'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All activities'),
                  ),
                  for (final e in names.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  activity = value == '' ? null : value;
                  limit = 50;
                }),
              ),
            ],
          ),
        ),
        Text('${matching.length} matching records · All dates'),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Times show when an outcome was recorded, in the local time saved with it. Older records may have no saved time.',
          ),
        ),
        if (matching.isEmpty)
          const ListTile(title: Text('No breaks recorded for this selection')),
        for (final group in groups.entries)
          ExpansionTile(
            key: PageStorageKey(
              'history-date-${group.key}-$selectedType-$selectedActivity',
            ),
            initiallyExpanded: true,
            title: Text('${group.key} (${group.value.length})'),
            children: [
              for (final record in group.value)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record['status']} • ${record['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(recordedTime(record)),
                        Text(
                          '${c.profiles.where((p) => p['id'] == (record['routine'] ?? record['routineId'])).firstOrNull?['name'] ?? 'Routine'} · ${record['category']}',
                        ),
                        if (record['status'] == 'Missed')
                          const Text('Unconfirmed break'),
                        if (record['confirmedAt'] != null)
                          const Text(
                            'Confirmed later; original record time retained',
                          ),
                        if (record['status'] != 'Completed')
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => c.confirmArchivedBreak(record['id']),
                            child: const Text('I took it'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (matching.length > limit)
          TextButton(
            onPressed: () => setState(() => limit += 50),
            child: const Text('Show 50 more records'),
          ),
      ],
    );
  }
}
