// SPDX-License-Identifier: Apache-2.0
import 'activity.dart';

const defaultProfiles = <Map<String, dynamic>>[
  {
    'id': 'short',
    'name': 'Screen rest',
    'trigger': 'screen',
    'enabled': true,
    'workSeconds': 1500,
    'resetSeconds': 30,
    'popup': true,
    'breakSeconds': 30,
    'categories': ['quiet'],
    'selection': 'rotation',
  },
  {
    'id': 'movement',
    'name': 'Movement break',
    'trigger': 'manual',
    'enabled': false,
    'workSeconds': 3000,
    'repeat': true,
    'breakSeconds': 120,
    'categories': ['movement', 'breathing'],
    'selection': 'rotation',
  },
  {
    'id': 'creative',
    'name': 'Creative break',
    'trigger': 'scheduled',
    'enabled': false,
    'minuteOfDay': 900,
    'breakSeconds': 300,
    'categories': ['quiz', 'imagination'],
    'selection': 'rotation',
  },
];

List<Activity> fittingActivities(
  List<Activity> all,
  Map<String, dynamic> profile,
  int seconds,
) {
  final enabled = ((profile['categories'] ?? categories) as List)
      .cast<String>();
  final disabled = ((profile['disabledActivities'] ?? []) as List)
      .cast<String>();
  return all
      .where(
        (a) =>
            enabled.contains(a.category) &&
            !disabled.contains(a.id) &&
            a.seconds <= seconds,
      )
      .toList();
}

Activity selectForProfile(
  List<Activity> all,
  Map<String, dynamic> profile,
  int seconds,
  String? previous,
) {
  final fit = fittingActivities(all, profile, seconds);
  if (profile['selection'] == 'fixed') {
    for (final a in fit) {
      if (a.id == profile['favourite']) return a;
    }
  }
  if (profile['selection'] == 'choose' || fit.isEmpty)
    return all.firstWhere((a) => a.id == 'quiet.soft');
  final index = fit.indexWhere((a) => a.id == previous);
  return fit[(index + 1) % fit.length];
}
