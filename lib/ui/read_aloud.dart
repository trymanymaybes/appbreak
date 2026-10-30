// SPDX-License-Identifier: Apache-2.0
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
  Companion get c => widget.controller;

  @override
  void initState() {
    super.initState();
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
          if (!c.device.isDesktop)
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    if ((c.profile['quiet'] ?? c.settings['quiet'] ?? true) ==
                        true) {
                      setState(() {
                        error = 'Turn off Quiet break to hear the page.';
                      });
                      return;
                    }
                    await c.narrate();
                    if (mounted)
                      setState(() {
                        error = c.error;
                      });
                  },
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Play page / restart'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await c.device.call('stopSpeech');
                    } catch (e) {
                      if (mounted)
                        setState(() {
                          error = '$e';
                        });
                    }
                  },
                  child: const Text('Stop'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    requestVersion++;
    url.dispose();
    super.dispose();
  }
}
