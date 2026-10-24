import 'package:flutter/material.dart';
import '../application/controller.dart';
import '../domain/routine_bundle.dart';

class RoutineBundlesPage extends StatelessWidget {
  final Companion controller;
  const RoutineBundlesPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Optional routine bundles')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(controller.bundleStatus),
          FilledButton(
            onPressed: controller.bundleBusy
                ? null
                : () => controller.refreshBundles(),
            child: const Text('Download / refresh catalogue'),
          ),
          const Text(
            'Content comes from the AppBreak repository. Preview before adding. Reminders and Android permissions are not enabled by installation.',
          ),
          for (final b in controller.routineBundles)
            Card(
              child: ListTile(
                title: Text(b.title),
                subtitle: Text(
                  '${b.data['description']}\nVersion ${b.version} · ${b.data['author']} · ${b.data['license']}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BundlePreview(controller: controller, bundle: b),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class BundlePreview extends StatefulWidget {
  final Companion controller;
  final RoutineBundle bundle;
  const BundlePreview({
    super.key,
    required this.controller,
    required this.bundle,
  });
  @override
  State<BundlePreview> createState() => _BundlePreviewState();
}

class _BundlePreviewState extends State<BundlePreview> {
  final overrides = <String, dynamic>{};
  final form = GlobalKey<FormState>();
  bool adding = false;
  String? message;
  @override
  Widget build(BuildContext context) {
    final b = widget.bundle;
    final installed = widget.controller.profiles
        .where((p) => p['bundleId'] == b.id)
        .firstOrNull;
    final updating =
        installed != null && b.version > (installed['bundleVersion'] ?? 1);
    final s = updating
        ? <String, dynamic>{
            for (final k in RoutineBundle.settingKeys)
              k: overrides[k] ?? installed[k] ?? b.data['defaults'][k],
          }
        : b.settings(overrides);
    final custom = b.data['customisable'] as List;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview and customise')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(b.title, style: Theme.of(context).textTheme.headlineSmall),
            Text(b.data['description']),
            Text(
              'Work activity: ${b.data['workActivity']}\nTrigger: ${s['trigger']}\nSelection: ${s['selection']}',
            ),
            Text(
              updating
                  ? 'Update installed version ${installed['bundleVersion']} to ${b.version}. Keeps the routine name, ID, reminder state, local settings, history and notes. Untouched bundle activity selections follow new dependencies.'
                  : 'Adds one editable routine, initially disabled, and saves required activities offline. Existing routines, progress and notes are kept.',
            ),
            Text(
              '${b.data['author']} · ${b.data['license']} · version ${b.version}',
            ),
            OutlinedButton(
              onPressed: adding
                  ? null
                  : () async {
                      setState(() => adding = true);
                      await widget.controller.refreshCatalog(
                        manual: true,
                        downloadOnly: true,
                      );
                      if (!mounted) return;
                      setState(() {
                        adding = false;
                        message = widget.controller.catalogStatus;
                      });
                    },
              child: const Text('Download required activities'),
            ),
            const Text(
              'Downloads the reviewed activity catalogue without enabling automatic updates or installing a routine. Add/update below validates every dependency.',
            ),
            for (final dep in b.data['dependencies'])
              Text(
                'Activity: ${dep['id']} (version ${dep['minimumVersion']} or later)',
              ),
            for (final k in ['workSeconds', 'breakSeconds'])
              TextFormField(
                initialValue: '${s[k]}',
                enabled: custom.contains(k),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: k == 'workSeconds'
                      ? 'Work interval (seconds)'
                      : 'Break duration (seconds)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  final min = k == 'workSeconds' ? 60 : 20;
                  final max = k == 'workSeconds' ? 14400 : 300;
                  return n == null || n < min || n > max
                      ? 'Enter $min–$max seconds'
                      : null;
                },
                onSaved: (v) {
                  if (custom.contains(k)) overrides[k] = int.parse(v!);
                },
              ),
            for (final k in ['quiet', 'repeat'])
              SwitchListTile(
                title: Text(
                  k == 'quiet'
                      ? 'Quiet narration mode'
                      : 'Repeat work intervals',
                ),
                value: s[k],
                onChanged: custom.contains(k)
                    ? (v) => setState(() => overrides[k] = v)
                    : null,
              ),
            if (custom.contains('trigger'))
              DropdownButtonFormField<String>(
                initialValue: s['trigger'],
                decoration: const InputDecoration(labelText: 'Trigger'),
                items: [
                  for (final v in ['manual', 'interval', 'screen'])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => setState(() => overrides['trigger'] = v),
              ),
            if (custom.contains('selection'))
              DropdownButtonFormField<String>(
                initialValue: s['selection'],
                decoration: const InputDecoration(
                  labelText: 'Activity selection',
                ),
                items: [
                  for (final v in ['rotation', 'fixed', 'choose'])
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => setState(() => overrides['selection'] = v),
              ),
            if (s['trigger'] == 'screen')
              const Text(
                'Screen-use tracking requires Usage access when you choose to enable it. Installation does not request access.',
              ),
            if (message != null) Text(message!, semanticsLabel: message),
            FilledButton(
              onPressed: adding
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      form.currentState!.save();
                      setState(() => adding = true);
                      await widget.controller.installBundle(
                        b,
                        overrides,
                        updateRoutineId: updating
                            ? installed['id'] as String
                            : null,
                      );
                      if (!mounted) return;
                      setState(() {
                        adding = false;
                        message =
                            widget.controller.error ??
                            (updating
                                ? 'Updated. Your settings and history were kept.'
                                : 'Added with reminders off. Edit or remove it in Routines.');
                      });
                    },
              child: Text(
                updating ? 'Update existing routine' : 'Add disabled routine',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
