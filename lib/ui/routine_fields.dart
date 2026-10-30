// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';

/// Form fields shared by new and existing routine editors.
List<Widget> routineFields(
  BuildContext context,
  Map<String, dynamic> p,
  void Function(VoidCallback) update,
) {
  Widget number(String key, String label, int fallback, int min, int max) =>
      TextFormField(
        key: ValueKey(key),
        initialValue: '${p[key] ?? fallback}',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, helperText: '$min–$max'),
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < min || n > max ? 'Enter $min–$max' : null;
        },
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) update(() => p[key] = n);
        },
      );
  Widget toggle(String key, String label, bool fallback) => SwitchListTile(
    title: Text(label),
    value: p[key] ?? fallback,
    onChanged: (v) => update(() => p[key] = v),
  );
  Widget choice(
    String key,
    String label,
    String fallback,
    Map<String, String> values,
  ) => DropdownButtonFormField<String>(
    initialValue: p[key] ?? fallback,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: values.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: (v) => update(() => p[key] = v),
  );
  final days = List<int>.from(p['days'] ?? [1, 2, 3, 4, 5, 6, 7]);
  return [
    TextFormField(
      key: const ValueKey('routine-name'),
      initialValue: p['name'],
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Routine name'),
      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
      onChanged: (v) => p['name'] = v.trim(),
    ),
    toggle('enabled', 'Enable routine', false),
    choice('trigger', 'When to remind', 'manual', {
      'screen': 'Automatic active-screen time',
      'manual': 'Manually started work session',
      'interval': 'Repeating elapsed-time interval',
      'scheduled': 'At a daily time',
    }),
    if (p['trigger'] != 'scheduled')
      number('workSeconds', 'Work interval (seconds)', 1500, 60, 14400),
    if (p['trigger'] == 'scheduled')
      ListTile(
        title: const Text('Reminder time'),
        subtitle: Text(
          TimeOfDay(
            hour: (p['minuteOfDay'] ?? 540) ~/ 60,
            minute: (p['minuteOfDay'] ?? 540) % 60,
          ).format(context),
        ),
        trailing: const Icon(Icons.schedule),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: (p['minuteOfDay'] ?? 540) ~/ 60,
              minute: (p['minuteOfDay'] ?? 540) % 60,
            ),
          );
          if (t != null)
            update(() => p['minuteOfDay'] = t.hour * 60 + t.minute);
        },
      ),
    number('breakSeconds', 'Break duration (seconds)', 30, 20, 300),
    if (p['trigger'] == 'screen') ...[
      toggle(
        'resetByBreak',
        'Reset after screen-off for the full break duration',
        false,
      ),
      if (p['resetByBreak'] != true)
        number(
          'resetSeconds',
          'Screen-off reset threshold (seconds)',
          30,
          1,
          3600,
        ),
      const Text(
        'Shorter screen-off periods pause counting. A reset earns no activity credit. Usage access is required.',
      ),
    ],
    if (p['trigger'] == 'manual')
      toggle('repeat', 'Repeat after completing or skipping a break', true),
    const Text('Days'),
    Wrap(
      children: [
        for (var d = 1; d <= 7; d++)
          FilterChip(
            label: Text(
              ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
            ),
            selected: days.contains(d),
            onSelected: (v) => update(() {
              v ? days.add(d) : days.remove(d);
              p['days'] = days;
            }),
          ),
      ],
    ),
    number('startHour', 'Active hours: start (24-hour clock)', 0, 0, 23),
    number('endHour', 'Active hours: end (same as start = all day)', 0, 0, 23),
    toggle('notifications', 'Notifications', true),
    toggle('popup', 'Popup when system permission allows', true),
    TextFormField(
      initialValue: p['message'] ?? 'Break ready. Start when you are ready.',
      maxLength: 200,
      decoration: const InputDecoration(labelText: 'Reminder text'),
      onChanged: (v) => p['message'] = v,
    ),
    DropdownButtonFormField<int>(
      initialValue: p['color'] ?? 0xff356859,
      decoration: const InputDecoration(labelText: 'Display colour'),
      items: const [
        DropdownMenuItem(value: 0xff356859, child: Text('Forest')),
        DropdownMenuItem(value: 0xff365e9d, child: Text('Blue')),
        DropdownMenuItem(value: 0xff754f84, child: Text('Plum')),
        DropdownMenuItem(value: 0xff89552e, child: Text('Clay')),
      ],
      onChanged: (v) => update(() => p['color'] = v),
    ),
    number('goal', 'Participation goal (0 = off)', 0, 0, 100),
    choice('goalPeriod', 'Goal period', 'daily', {
      'daily': 'Daily',
      'weekly': 'Weekly (Monday–Sunday)',
    }),
    const Text(
      'Goals count confirmed participation once per break. Quiet rest counts too.',
    ),
  ];
}
