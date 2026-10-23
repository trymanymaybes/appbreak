import 'package:flutter/material.dart';
import '../application/controller.dart';

class VoiceSetup extends StatefulWidget {
  final Companion controller;
  const VoiceSetup({super.key, required this.controller});
  @override
  State<VoiceSetup> createState() => _VoiceSetupState();
}

class _VoiceSetupState extends State<VoiceSetup> with WidgetsBindingObserver {
  String status = 'Install an offline English voice for narration.';
  bool installing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && installing) {
      installing = false;
      refresh();
    }
  }

  Future<void> refresh() async {
    try {
      await widget.controller.device.call('refreshVoices');
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) await check();
    } catch (e) {
      if (mounted)
        setState(
          () => status =
              'Open Android Text-to-speech settings and install English.',
        );
    }
  }

  Future<void> check() async {
    try {
      final list = await widget.controller.device.call<List>('voices') ?? [];
      final voices =
          list.where((v) => (v['language'] as String).startsWith('en')).toList()
            ..sort(
              (a, b) => (a['language'] == 'en-IN' ? 0 : 1).compareTo(
                b['language'] == 'en-IN' ? 0 : 1,
              ),
            );
      if (voices.isEmpty) {
        if (mounted)
          setState(
            () => status =
                'No offline English voice found. Install English, then check again.',
          );
        return;
      }
      await widget.controller.updateSettings({'voice': voices.first['name']});
      if (mounted)
        setState(
          () => status = 'English voice ready: ${voices.first['language']}',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => status = 'Speech engine still starting. Check again shortly.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('English voice setup'),
    subtitle: Text(status),
    children: [
      const Text(
        'Android handles the voice download. Select English in its installer. Offline narration is used after installation.',
      ),
      Wrap(
        children: [
          TextButton(
            onPressed: check,
            child: const Text('Check English voice'),
          ),
          TextButton(
            onPressed: () async {
              try {
                installing = true;
                await widget.controller.device.call('installVoice');
              } catch (e) {
                installing = false;
                if (mounted)
                  setState(
                    () => status =
                        'Open Android Settings → Text-to-speech → Install voice data → English.',
                  );
              }
            },
            child: const Text('Install English voice'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await widget.controller.device.call('speak', {
                  'language': 'en-IN',
                  'steps': [
                    {
                      'kind': 'instruction',
                      'text': 'Your English voice is ready.',
                    },
                  ],
                });
              } catch (e) {
                if (mounted)
                  setState(() => status = 'Install English and check again.');
              }
            },
            child: const Text('Test voice'),
          ),
        ],
      ),
    ],
  );
}
