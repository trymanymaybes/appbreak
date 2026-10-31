// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:flutter/material.dart';
import '../application/controller.dart';
import '../services/read_aloud.dart';

class ReadAloudView extends StatefulWidget {
  final Companion controller;
  final ReadAloudSource? source;
  const ReadAloudView({super.key, required this.controller, this.source});
  @override
  State<ReadAloudView> createState() => _ReadAloudViewState();
}

class _ReadAloudViewState extends State<ReadAloudView> {
  late final TextEditingController url;
  bool loading = false;
  String? error;
  int requestVersion = 0;
  Timer? playbackTimer;
  String playback = 'stopped';

  Future<void> refreshPlayback() async {
    if (c.device.isDesktop) return;
    try {
      final state = await c.device.call<Map>('readAloudState');
      if (!mounted || state == null) return;
      final next = state['state'] as String? ?? 'stopped';
      final message = state['error'] as String?;
      if (playback != next || (message != null && error != message)) {
        setState(() { playback = next; if (message != null) error = message; });
      }
    } catch (_) { /* Playback actions surface native errors. */ }
  }

  Future<void> control(String action) async {
    try {
      await c.device.call('readAloudControl', {'action': action});
      await refreshPlayback();
    } catch (e) {
      if (mounted) setState(() { error = '$e'; });
    }
  }
  Companion get c => widget.controller;

  @override
  void initState() {
    super.initState();
    refreshPlayback();
    playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => refreshPlayback());
    url = TextEditingController(
      text: c.settings['readAloudUrl'] as String? ?? '',
    );
  }

  Future<void> load() async {
    final version = ++requestVersion;
    final sessionId = c.session.id;
    final activityId = c.current?.id;
    setState(() {
      loading = true;
      error = null;
    });
    c.readAloudArticle = null;
    try {
      await c.device.call('stopSpeech');
      final value = ReadAloudSource.validateUrl(url.text).toString();
      final article = await (widget.source ?? ReadAloudSource()).load(value);
      if (!mounted ||
          version != requestVersion ||
          c.disposed ||
          c.session.id != sessionId ||
          c.current?.id != activityId)
        return;
      // Remember only the URL; article content stays in memory.
      await c.updateSettings({'readAloudUrl': value});
      if (!mounted ||
          version != requestVersion ||
          c.disposed ||
          c.session.id != sessionId ||
          c.current?.id != activityId)
        return;
      c.readAloudArticle = article;
      setState(() {
        error = c.error;
      });
    } catch (e) {
      if (mounted && version == requestVersion)
        setState(() {
          error = '$e';
        });
    } finally {
      if (mounted && version == requestVersion)
        setState(() {
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = c.readAloudArticle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Page URL',
            hintText: 'https://example.com/article',
          ),
          onChanged: (_) async {
            requestVersion++;
            setState(() {
              loading = false;
              error = null;
              c.readAloudArticle = null;
            });
            try {
              await c.device.call('stopSpeech');
            } catch (_) {
              /* Native error is shown by Play. */
            }
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.download_outlined),
            label: Text(loading ? 'Loading page…' : 'Load page'),
          ),
        ),
        const Text(
          'Public HTML or text pages only. Check the preview: some sites hide their article behind a login or load it with JavaScript. Loading uses the internet; speech uses your installed voice.',
        ),
        if (c.device.isDesktop)
          const Text(
            'Desktop preview supports loading and reading text. Narration is currently available on Android only.',
          ),
        if (error != null) Text(error!),
        if (article != null) ...[
          Text('${article.title} • ${article.language}'),
          ExpansionTile(
            title: const Text('Preview extracted text'),
            children: [SelectableText(article.text)],
          ),
        ],
        if (!c.device.isDesktop && (article != null || playback != 'stopped'))
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: loading || playback == 'loading' ? null : () async {
                  if (playback == 'playing') { await control('pause'); return; }
                  if ((c.profile['quiet'] ?? c.settings['quiet'] ?? true) == true) {
                    setState(() { error = 'Turn off Quiet break to hear the page.'; });
                    return;
                  }
                  if (playback == 'paused') {
                    await control('resume');
                  } else {
                    await c.narrate();
                    if (mounted) setState(() { error = c.error; });
                    await refreshPlayback();
                  }
                },
                icon: Icon(playback == 'playing' ? Icons.pause : Icons.play_arrow),
                label: Text(playback == 'playing' ? 'Pause' : playback == 'paused' ? 'Resume' : playback == 'loading' ? 'Preparing voice…' : 'Play page'),
              ),
              TextButton(
                onPressed: playback == 'stopped' || loading ? null : () => control('restart'),
                child: const Text('Restart'),
              ),
              TextButton(
                onPressed: () async {
                  await c.device.call('stopSpeech');
                  await refreshPlayback();
                },
                child: const Text('Stop'),
              ),
            ],
          ),
        if (!c.device.isDesktop)
          const Text('Playback continues with the screen off, until the break ends. Pause/Resume is also available in the playback notification.'),
      ],
    );
  }

  @override
  void dispose() {
    requestVersion++;
    playbackTimer?.cancel();
    url.dispose();
    super.dispose();
  }
}
