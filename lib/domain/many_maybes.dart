// SPDX-License-Identifier: Apache-2.0
import 'activity.dart';

const manyMaybesOrigin = 'https://trymanymaybes.github.io';
bool isChallengeNumber(String value) => RegExp(r'^\d{1,8}$').hasMatch(value);

class ManyMaybesChallenge {
  final String number, title, description, alt, imageUrl;
  const ManyMaybesChallenge({
    required this.number,
    required this.title,
    required this.description,
    required this.alt,
    required this.imageUrl,
  });
  String get activityId => 'manymaybes.challenge-$number';
  String get url => '$manyMaybesOrigin/challenge-$number.html';
  String get narration => description.trim().isNotEmpty ? description : alt;
  String get spokenPrompt =>
      '${description.trim().isNotEmpty && alt.trim().isNotEmpty ? '$alt. ' : ''}$narration Look at the starter, or picture it from the description. Look away if you like and imagine what these marks could become. Keep the original marks in place. What would you add?';
  Activity toActivity() => Activity({
    'schemaVersion': 1,
    'id': activityId,
    'title': 'Many Maybes $number: $title',
    'category': 'imagination',
    'language': 'en-IN',
    'estimatedSeconds': 120,
    'description': narration,
    'steps': [
      {'kind': 'instruction', 'text': spokenPrompt},
      {'kind': 'thinking', 'seconds': 50},
      {
        'kind': 'narration',
        'text':
            'Have an idea you like? Talk it through and record it, or dictate a written note. Review it in Ideas before choosing to submit. Sharing is optional.',
      },
      {'kind': 'completion', 'text': 'Keep your possibility, or try another.'},
    ],
    'requiresVisualAttention': false,
    'requiresInput': false,
    'accessibleAlternatives': [
      'Listen to the description or imagine the marks. Drawing and recording are optional.',
    ],
    'author': 'Many Maybes',
    'attribution': url,
    'contentLicense': 'CC-BY-4.0',
    'manyMaybes': {
      'number': number,
      'title': title,
      'description': description,
      'alt': alt,
      'imageUrl': imageUrl,
    },
  });
  static ManyMaybesChallenge? fromActivity(Activity? activity) {
    final m = activity?.data['manyMaybes'];
    if (m is! Map || !isChallengeNumber('${m['number']}')) return null;
    if ([
      'number',
      'title',
      'description',
      'alt',
      'imageUrl',
    ].any((key) => m[key] is! String))
      return null;
    if (m['imageUrl'] != '') {
      final uri = Uri.tryParse(m['imageUrl']);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'trymanymaybes.github.io' ||
          uri.hasPort ||
          uri.userInfo.isNotEmpty)
        return null;
    }
    return ManyMaybesChallenge(
      number: m['number'],
      title: m['title'],
      description: m['description'],
      alt: m['alt'],
      imageUrl: m['imageUrl'],
    );
  }
}
