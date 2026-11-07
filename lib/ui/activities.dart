// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../application/controller.dart';
import '../domain/activity.dart';

class ActivitiesPanel extends StatelessWidget {
  final Companion controller;
  const ActivitiesPanel({super.key, required this.controller});

  Future<void> edit(
    BuildContext context, [
    Activity? activity,
    bool personal = true,
  ]) async {
    final title = TextEditingController(text: activity?.title ?? '');
    final instructions = TextEditingController(
      text: activity?.data['description'] ?? '',
    );
    final duration = TextEditingController(text: '${activity?.seconds ?? 30}');
    var category = activity?.category ?? 'quiet';
    final form = GlobalKey<FormState>();
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            personal
                ? (activity == null
                      ? 'Create custom break'
                      : 'Edit custom break')
                : activity!.title,
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (personal) ...[
                      TextFormField(
                        controller: title,
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                      TextFormField(
                        controller: instructions,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter instructions'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categories
                            .where((c) => c != 'read-aloud')
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: saving ? null : (v) => category = v!,
                      ),
                    ] else
                      Text(activity!.data['description'] ?? activity.text),
                    TextFormField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration for activity selection',
                        helperText: 'In seconds · 20–300',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 20 || n > 300
                            ? 'Enter 20–300 seconds'
                            : null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'An activity joins the cycle when this duration fits within the routine’s break time and its category is enabled. The routine controls the timer. Press Complete when you are ready, at timer expiry or after finishing the activity. Changes apply to future breaks.',
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (!personal)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        await controller.setActivityDuration(
                          activity!.id,
                          null,
                        );
                        if (!context.mounted) return;
                        if (controller.error == null) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            saving = false;
                            error = controller.error;
                          });
                        }
                      },
                child: const Text('Reset duration'),
              ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => saving = true);
                      if (personal) {
                        await controller.savePersonalActivity(
                          id: activity?.id,
                          title: title.text,
                          instructions: instructions.text,
                          category: category,
                          seconds: int.parse(duration.text),
                        );
                      } else {
                        await controller.setActivityDuration(
                          activity!.id,
                          int.parse(duration.text),
                        );
                      }
                      if (!context.mounted) return;
                      if (controller.error == null) {
                        Navigator.pop(context);
                      } else {
                        setState(() {
                          saving = false;
                          error = controller.error;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // The dialog route may still animate after showDialog completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    instructions.dispose();
    duration.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = controller.personalActivityIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Activities', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          'Set activity durations for inclusion in the routine’s activity cycle, or create up to 3 custom activities. The routine sets the break timer; you decide when to press Complete.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: ids.length >= 3 || controller.busy
              ? null
              : () => edit(context),
          icon: const Icon(Icons.add),
          label: Text('Create custom break (${ids.length}/3)'),
        ),
        if (ids.length >= 3)
          const Text(
            'All 3 custom break slots are used. Edit or delete one to make room.',
          ),
        TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Contribute a new activity on GitHub'),
          onPressed: () async {
            try {
              final opened = await launchUrl(
                Uri.parse(
                  'https://github.com/trymanymaybes/appbreak/blob/main/CONTRIBUTING.md',
                ),
                mode: LaunchMode.externalApplication,
              );
              if (!opened) throw StateError('Could not open browser');
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open GitHub. Visit github.com/trymanymaybes/appbreak and open CONTRIBUTING.md.',
                    ),
                  ),
                );
            }
          },
        ),
        for (final personal in [true, false]) ...[
          Text(
            personal ? 'Your custom breaks' : 'All other activities',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (personal && ids.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Create your first custom break above. It stays on this device.',
              ),
            ),
          for (final a in controller.activities.where(
            (a) => ids.contains(a.id) == personal,
          ))
            Card(
              child: ListTile(
                title: Text(a.title),
                subtitle: Text(
                  '${a.category} · Selection duration: ${a.seconds}s',
                ),
                onTap: controller.busy
                    ? null
                    : () => edit(context, a, personal),
                trailing: personal
                    ? IconButton(
                        tooltip: 'Delete ${a.title}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: controller.busy
                            ? null
                            : () async {
                                final remove = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete ${a.title}?'),
                                    content: const Text(
                                      'This frees a custom break slot. Existing break history is kept.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (remove == true)
                                  await controller.deletePersonalActivity(a.id);
                              },
                      )
                    : const Icon(Icons.edit_outlined),
              ),
            ),
        ],
      ],
    );
  }
}
