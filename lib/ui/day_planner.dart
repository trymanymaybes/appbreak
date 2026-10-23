import 'package:flutter/material.dart';
import '../application/controller.dart';

class DayPlanner extends StatefulWidget {
  final Companion controller;
  const DayPlanner({super.key, required this.controller});
  @override
  State<DayPlanner> createState() => _DayPlannerState();
}

class _DayPlannerState extends State<DayPlanner> {
  DateTime day = DateUtils.dateOnly(DateTime.now());
  Companion get c => widget.controller;
  String get date => day.toIso8601String().substring(0, 10);
  Future<void> edit([Map<String, dynamic>? p]) async {
    final title = TextEditingController(text: p?['title'] ?? '');
    final minutes = TextEditingController(text: '${p?['minutes'] ?? 60}');
    var minute = p?['minute'] ?? 540;
    var routine = p?['routine'] ?? c.profiles.first['id'];
    if (!c.profiles.any((r) => r['id'] == routine))
      routine = c.profiles.first['id'];
    final days = List<int>.from(p?['days'] ?? []);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Plan activity'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Activity name',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                          hour: minute ~/ 60,
                          minute: minute % 60,
                        ),
                      );
                      if (t != null) set(() => minute = t.hour * 60 + t.minute);
                    },
                    child: Text(
                      'Starts ${TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(ctx)}',
                    ),
                  ),
                  TextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration: 1–720 minutes',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: routine,
                    items: c.profiles
                        .map(
                          (r) => DropdownMenuItem<String>(
                            value: r['id'],
                            child: Text(r['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => set(() => routine = v!),
                    decoration: const InputDecoration(
                      labelText: 'Break routine',
                    ),
                  ),
                  const Text(
                    'Repeat on selected weekdays. Leave empty for this date only.',
                  ),
                  Wrap(
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          const ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'][i],
                        ),
                        selected: days.contains(i + 1),
                        onSelected: (v) =>
                            set(() => v ? days.add(i + 1) : days.remove(i + 1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(minutes.text);
                if (title.text.trim().isNotEmpty &&
                    n != null &&
                    n >= 1 &&
                    n <= 720)
                  Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true)
      await c.savePlan({
        'id': p?['id'] ?? 'plan-${DateTime.now().microsecondsSinceEpoch}',
        'title': title.text.trim(),
        'date': p?['date'] ?? date,
        'minute': minute,
        'minutes': int.parse(minutes.text),
        'days': days,
        'routine': routine,
      });
    title.dispose();
    minutes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans =
        c.plans
            .where(
              (p) => (p['days'] as List).isEmpty
                  ? p['date'] == date
                  : date.compareTo(p['date']) >= 0 &&
                        (p['days'] as List).contains(day.weekday),
            )
            .toList()
          ..sort((a, b) => (a['minute'] as int).compareTo(b['minute'] as int));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Day',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: () =>
                  setState(() => day = day.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(date),
            IconButton(
              tooltip: 'Next day',
              onPressed: () =>
                  setState(() => day = day.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => edit(),
              child: const Text('Plan activity'),
            ),
          ],
        ),
        const Text(
          'Plans invite you to start; time passing never earns completion. Background alerts may be delayed by Android.',
        ),
        if (plans.isEmpty) const Text('No activities planned.'),
        for (final p in plans)
          Builder(
            builder: (context) {
              final r =
                  (c.data['planRecords'] as Map? ?? {})['${p['id']}@$date']
                      as Map? ??
                  {};
              final status =
                  r['status'] ??
                  (DateTime.now().isAfter(
                        day.add(Duration(minutes: p['minute'] + p['minutes'])),
                      )
                      ? 'missed'
                      : 'planned');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${TimeOfDay(hour: p['minute'] ~/ 60, minute: p['minute'] % 60).format(context)} · ${p['minutes']} min · $status',
                      ),
                      if (r['remindAt'] != null)
                        Text(
                          'Reminder: ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(r['remindAt'])).format(context)}',
                        ),
                      Wrap(
                        children: [
                          for (final a in [
                            ('start', 'Start now'),
                            ('delay', 'Delay 10 min'),
                            ('complete', 'Mark completed'),
                            ('extend', 'Extend 15 min'),
                            ('skip', 'Skip block'),
                          ])
                            if (switch (a.$1) {
                              'start' => [
                                'planned',
                                'prompted',
                                'delayed',
                                'missed',
                              ].contains(status),
                              'delay' => [
                                'planned',
                                'prompted',
                                'delayed',
                              ].contains(status),
                              'complete' => [
                                'active',
                                'ended',
                              ].contains(status),
                              'extend' => status == 'active',
                              _ => !['completed', 'skipped'].contains(status),
                            })
                              TextButton(
                                onPressed: () =>
                                    c.planAction(p['id'], date, a.$1),
                                child: Text(a.$2),
                              ),
                          if (status != 'active')
                            TextButton(
                              onPressed: () => edit(p),
                              child: const Text('Edit'),
                            ),
                          if (status != 'active')
                            TextButton(
                              onPressed: () =>
                                  c.planAction(p['id'], date, 'delete'),
                              child: const Text('Delete plan'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
