import 'content_media.dart';
import 'package:flutter/material.dart';
import '../application/controller.dart';
import '../domain/many_maybes.dart';
import '../domain/session.dart';
import '../services/many_maybes_site.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ManyMaybesChallengeView extends StatefulWidget {
  final Companion controller;
  final ManyMaybesSite? site;
  const ManyMaybesChallengeView({
    super.key,
    required this.controller,
    this.site,
  });
  @override
  State<ManyMaybesChallengeView> createState() =>
      _ManyMaybesChallengeViewState();
}

class _ManyMaybesChallengeViewState extends State<ManyMaybesChallengeView> {
  late final ManyMaybesSite site = widget.site ?? ManyMaybesSite();
  List<String> numbers = [];
  bool loading = false;
  String? message;
  Companion get c => widget.controller;
  String? get number => challengeFor(c.session.activity);
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant ManyMaybesChallengeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // General activity browsing can change the active challenge too.
    if (!loading && number != loadedNumber) refresh();
  }

  String? loadedNumber;
  Future<void> refresh() async {
    if (loading || number == null) return;
    setState(() {
      loading = true;
      message = null;
    });
    try {
      numbers = await site.index();
    } catch (_) {
      if (numbers.isEmpty) {
        numbers =
            c.activities
                .map((a) => challengeFor(a.id))
                .whereType<String>()
                .toSet()
                .toList()
              ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      }
      message =
          'Site unavailable. Previously loaded challenges and text remain available. Retry when online.';
    }
    if (!mounted) return;
    final target = number;
    loading = false;
    if (target != null) await load(target);
  }

  Future<void> load(String target) async {
    if (loading) return;
    final sessionId = c.session.id;
    final previousActivity = c.session.activity;
    if (previousActivity == null) return;
    setState(() => loading = true);
    try {
      final challenge = await site.challenge(target);
      if (!mounted) return;
      await c.useChallenge(
        challenge,
        sessionId: sessionId,
        previousActivity: previousActivity,
      );
      if (c.error != null) message = c.error;
      loadedNumber = number;
    } catch (_) {
      if (!mounted) return;
      final cached = c.activities
          .where((a) => a.id == 'manymaybes.challenge-$target')
          .firstOrNull;
      final saved = ManyMaybesChallenge.fromActivity(cached);
      if (saved != null) {
        await c.useChallenge(
          saved,
          sessionId: sessionId,
          previousActivity: previousActivity,
        );
      }
      // Navigation never replaces the current activity with an empty page.
      message = saved != null
          ? 'Showing previously loaded challenge text. Images need internet. Retry to check for updates.'
          : 'Could not load this challenge. Your current challenge is still here. Retry when online.';
      loadedNumber = number;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ManyMaybesChallenge.fromActivity(c.current);
    final current = number;
    if (current == null) return const SizedBox.shrink();
    final disabled = (c.profile['disabledActivities'] as List? ?? []);
    final choices = numbers
        .where((n) => !disabled.contains('manymaybes.challenge-$n'))
        .toList();
    final index = choices.indexOf(current);
    final canMove =
        c.session.phase == Phase.rest &&
        !c.busy &&
        !loading &&
        choices.length > 1;
    Widget fallback() => Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Image unavailable. ${challenge?.alt ?? 'Use the written challenge below.'}',
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Many Maybes · Challenge $current${index >= 0 ? ' · ${index + 1} of ${choices.length}' : ''}',
          textAlign: TextAlign.center,
        ),
        if (loading)
          const LinearProgressIndicator(
            semanticsLabel: 'Loading challenge from Many Maybes',
          ),
        if (message != null) Text(message!),
        const SizedBox(height: 12),
        if (challenge != null && challenge.imageUrl.isNotEmpty)
          SizedBox(
            height: 240,
            child: Uri.parse(challenge.imageUrl).path.endsWith('.svg')
                ? SvgPicture.network(
                    challenge.imageUrl,
                    fit: BoxFit.contain,
                    semanticsLabel: challenge.alt,
                    placeholderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, _, _) => fallback(),
                  )
                : CachedContentImage(
                    url: challenge.imageUrl,
                    alt: challenge.alt,
                    fallback: 'Image unavailable. ${challenge.alt}',
                    height: 240,
                  ),
          ),
        if (challenge != null)
          Text(challenge.alt, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: canMove
                  ? () => load(choices[(index - 1) % choices.length])
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous challenge'),
            ),
            OutlinedButton.icon(
              onPressed: canMove
                  ? () => load(choices[(index + 1) % choices.length])
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next challenge'),
            ),
            TextButton(
              onPressed: loading ? null : refresh,
              child: const Text('Refresh challenges'),
            ),
            TextButton(
              onPressed: () => openManyMaybes(
                context,
                c,
                '$manyMaybesOrigin/challenge-$current.html',
              ),
              child: const Text('View challenge on Many Maybes'),
            ),
          ],
        ),
        if (choices.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('challenge-picker-$current-${choices.length}'),
            initialValue: choices.contains(current) ? current : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Jump to challenge'),
            items: choices
                .map(
                  (n) =>
                      DropdownMenuItem(value: n, child: Text('Challenge $n')),
                )
                .toList(),
            onChanged: !loading && c.session.phase == Phase.rest
                ? (n) {
                    if (n != null && n != current) load(n);
                  }
                : null,
          ),
        const Text(
          'Imagine a possibility. You can look away and listen. Use Play / replay instructions; turn off Quiet break for narration. Images load directly from Many Maybes and need internet.',
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

String? challengeFor(dynamic activity) => RegExp(
  r'^manymaybes\.challenge-(\d{1,8})$',
).firstMatch('$activity')?.group(1);
Future<void> openManyMaybes(
  BuildContext context,
  Companion c,
  String url,
) async {
  try {
    await c.device.call('openExternal', {'url': url});
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this page. Check that a browser is installed.',
          ),
        ),
      );
  }
}

class ManyMaybes extends StatelessWidget {
  final Companion controller;
  final String? challenge;
  const ManyMaybes({super.key, required this.controller, this.challenge});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Many Maybes · Imagination'),
    subtitle: const Text('Full challenges and video introductions'),
    children: [
      const Text(
        'Videos open externally and need internet. Some require account access. Watching does not mark a break completed.',
      ),
      ListTile(
        title: Text(
          challenge == null
              ? 'Browse all challenges on the site'
              : 'Challenge $challenge on the site',
        ),
        onTap: () => openManyMaybes(
          context,
          controller,
          challenge == null
              ? '$manyMaybesOrigin/challenges.html'
              : '$manyMaybesOrigin/challenge-$challenge.html',
        ),
      ),
      if (challenge == null || challenge == '01') ...[
        TextButton(
          onPressed: () => openManyMaybes(
            context,
            controller,
            'https://youtube.com/shorts/D2JOLkmFzww',
          ),
          child: const Text('Challenge 01 · YouTube intro (may be private)'),
        ),
        TextButton(
          onPressed: () => openManyMaybes(
            context,
            controller,
            'https://www.instagram.com/trymanymaybe/reel/DeYGYIKhzDz/',
          ),
          child: const Text('Challenge 01 · Instagram intro'),
        ),
      ],
      if (challenge == null || challenge == '03')
        TextButton(
          onPressed: () => openManyMaybes(
            context,
            controller,
            'https://www.instagram.com/p/Delv3sfNZDqvQa3t_MGdq8DXa2etke7ImXXO740/',
          ),
          child: const Text(
            'Challenge 03 · Instagram intro (may require approval)',
          ),
        ),
      TextButton(
        onPressed: () => openManyMaybes(
          context,
          controller,
          'https://www.youtube.com/@trymanymaybes',
        ),
        child: const Text('More YouTube videos'),
      ),
      TextButton(
        onPressed: () => openManyMaybes(
          context,
          controller,
          'https://www.instagram.com/trymanymaybe/',
        ),
        child: const Text('More Instagram reels'),
      ),
    ],
  );
}

Future<void> submitIdea(
  BuildContext context,
  Companion c,
  Map<String, dynamic> note,
) async {
  final challenge = challengeFor(note['activity']);
  if (challenge == null) return;
  final summary = TextEditingController(text: note['text'] ?? '');
  var exported = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Submit idea · Challenge $challenge'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Review a written version of your idea. For a voice note, listen first and write or dictate a summary. Audio stays on this device.',
              ),
              TextField(
                controller: summary,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Idea card text'),
              ),
              const Text(
                'Save the idea card, then open the submission page and select that image. Sign in, choose publication permission, and press Submit for review there. Nothing is uploaded by this app.',
              ),
              if (exported)
                const Text('Card saved. Select it on the submission page.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              if (summary.text.trim().isEmpty) return;
              try {
                final result = await c.device.call<String>('saveIdeaCard', {
                  'text': summary.text.trim(),
                  'challenge': challenge,
                });
                if (ctx.mounted && result != null) set(() => exported = true);
              } catch (e) {
                if (ctx.mounted)
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('1. Save idea card'),
          ),
          FilledButton(
            onPressed: exported
                ? () => openManyMaybes(
                    ctx,
                    c,
                    'https://trymanymaybes.github.io/submit.html?challenge=$challenge',
                  )
                : null,
            child: const Text('2. Open submission'),
          ),
        ],
      ),
    ),
  );
  summary.dispose();
}
