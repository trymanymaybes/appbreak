// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../application/controller.dart';

class ReminderStatus extends StatelessWidget {
  final Companion controller;
  const ReminderStatus({super.key, required this.controller});

  String time(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal().toString().split('.').first
      : 'Not recorded';

  @override
  Widget build(BuildContext context) {
    final health = controller.reminderHealth;
    final routines = health['routines'] as Map? ?? {};
    final issues = health['issues'] as List? ?? [];
    return ExpansionTile(
      title: const Text('Reminder status & issues'),
      subtitle: Text('${issues.length} recorded issues'),
      children: [
        const ListTile(
          title: Text('Recovery checks run automatically'),
          subtitle: Text('Unanswered reminders retry at least five minutes apart, up to three attempts. A popup and its matching notification count once. Android may delay delivery; posting is not proof you saw it.'),
        ),
        if (health['exactAlarms'] == false)
          ListTile(
            title: const Text('Precise reminder timing is not enabled'),
            subtitle: const Text('Optional Android access can reduce timing delays. Battery restrictions can still apply.'),
            trailing: TextButton(
              onPressed: () async {
                await controller.device.call('exactAlarms');
              },
              child: const Text('Allow'),
            ),
          ),
        for (final item in routines.entries)
          ListTile(
            title: Text(controller.profiles.where((p) => p['id'] == item.key).firstOrNull?['name'] as String? ?? item.key.toString()),
            subtitle: Text('Last notification: ${time(item.value['lastNotificationAt'])}\nLast popup: ${time(item.value['lastPopupAt'])}\nLast response: ${time(item.value['lastResponseAt'])}\nUnanswered attempts: ${item.value['unanswered'] ?? 0}'),
          ),
        for (final issue in issues.reversed)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(issue['message'] as String),
            subtitle: Text('${issue['routine']} · ${time(issue['at'])}'),
          ),
      ],
    );
  }
}
