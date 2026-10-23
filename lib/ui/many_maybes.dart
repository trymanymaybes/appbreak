import 'package:flutter/material.dart';
import '../application/controller.dart';

String? challengeFor(dynamic activity) => RegExp(
  r'^manymaybes\.challenge-(\d{2})$',
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
      for (final n
          in challenge == null
              ? ['01', '02', '03', '04', '05', '06']
              : [challenge!])
        ListTile(
          title: Text('Challenge $n'),
          onTap: () => openManyMaybes(
            context,
            controller,
            'https://trymanymaybes.github.io/challenge-$n.html',
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
