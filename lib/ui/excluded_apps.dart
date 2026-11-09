import 'package:flutter/material.dart';
import '../application/controller.dart';

class ExcludedAppsPage extends StatefulWidget {
  final Companion controller;
  const ExcludedAppsPage({super.key, required this.controller});
  @override
  State<ExcludedAppsPage> createState() => _ExcludedAppsPageState();
}

class _ExcludedAppsPageState extends State<ExcludedAppsPage>
    with WidgetsBindingObserver {
  Companion get c => widget.controller;
  List<Map<String, dynamic>> apps = [];
  bool loading = true, usage = false, saving = false;
  String query = '';
  String? error;
  Set<String> get selected =>
      (c.settings['excludedApps'] as List? ?? []).cast<String>().toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    try {
      final installed = await c.device.call<List>('installedApps') ?? [];
      final capabilities = await c.device.call<Map>('capabilities') ?? {};
      if (!mounted) return;
      setState(() {
        apps = installed
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList();
        usage = capabilities['usage'] == true;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Could not load apps. Please retry.';
        });
    }
  }

  Future<void> toggle(String package, bool enabled) async {
    if (c.busy) return;
    final previous = selected;
    setState(() => saving = true);
    try {
      final next = selected;
      enabled ? next.add(package) : next.remove(package);
      await c.updateSettings({'excludedApps': next.toList()..sort()});
      if (c.error != null) {
        c.data['settings'] = {...c.settings, 'excludedApps': previous.toList()};
        throw StateError(c.error!);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save excluded apps. Please retry.'),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = [...apps];
    for (final package in selected) {
      if (!choices.any((a) => a['package'] == package)) {
        choices.add({'package': package, 'label': package});
      }
    }
    final visible = choices
        .where(
          (a) => '${a['label']} ${a['package']}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Excluded apps')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select apps such as Maps or your navigator. All break popups are suppressed while a selected app is in the foreground. Notifications and timers continue with your existing settings. Tapping a notification still opens the break.',
            ),
          ),
          if (!usage)
            ListTile(
              title: const Text('Usage access needed'),
              subtitle: const Text(
                'Allow AppBreak to detect the active app. With exclusions selected, unavailable detection keeps all alerts notification-only.',
              ),
              trailing: TextButton(
                onPressed: () async {
                  try {
                    await c.device.call('usageAccess');
                  } catch (_) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open Android Settings → Special app access → Usage access.',
                          ),
                        ),
                      );
                  }
                },
                child: const Text('Allow'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Only your selected app IDs are saved locally and included in exported backups. App usage history is not saved. Background navigation and picture-in-picture detection are not supported.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search apps',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          if (error != null)
            ListTile(
              title: Text(error!),
              trailing: TextButton(onPressed: load, child: const Text('Retry')),
            ),
          if (loading) const LinearProgressIndicator(),
          if (!loading && visible.isEmpty)
            const ListTile(title: Text('No matching apps')),
          for (final app in visible)
            CheckboxListTile(
              key: ValueKey(app['package']),
              title: Text(app['label'] as String),
              subtitle: Text(app['package'] as String),
              value: selected.contains(app['package']),
              onChanged: saving
                  ? null
                  : (value) => toggle(app['package'] as String, value == true),
            ),
        ],
      ),
    );
  }
}
