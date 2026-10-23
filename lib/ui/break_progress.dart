import 'package:flutter/material.dart';
import '../application/controller.dart';
import '../domain/break_counts.dart';

class BreakProgress extends StatefulWidget {
  final Companion controller;
  const BreakProgress({super.key, required this.controller});
  @override
  State<BreakProgress> createState() => _BreakProgressState();
}

class _BreakProgressState extends State<BreakProgress> {
  String period = 'Today';
  @override
  Widget build(BuildContext context) {
    final records = inPeriod(
      widget.controller.breakRecords,
      period,
      DateTime.now(),
    );
    final counts = countByType(records);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: ['Today', 'This week', 'All time']
              .map(
                (p) => ChoiceChip(
                  label: Text(p),
                  selected: period == p,
                  onSelected: (_) => setState(() => period = p),
                ),
              )
              .toList(),
        ),
        Text(
          '${records.where((r) => r['status'] == 'Completed').length} completed · ${records.where((r) => r['status'] == 'Skipped').length} skipped · ${records.where((r) => r['status'] == 'Missed').length} missed',
        ),
        const Text(
          'Skipped means you chose Skip. Missed means unanswered. Only completed breaks earn achievements.',
        ),
        for (final e in counts.entries)
          if (e.key != 'unknown' || e.value.values.any((n) => n > 0))
            ListTile(
              title: Text(
                e.key == 'quiet'
                    ? 'Quiet rest'
                    : e.key == 'unknown'
                    ? 'Unclassified older breaks'
                    : e.key[0].toUpperCase() + e.key.substring(1),
              ),
              subtitle: Text(
                '${e.value['Completed']} completed · ${e.value['Skipped']} skipped · ${e.value['Missed']} missed',
              ),
            ),
      ],
    );
  }
}
