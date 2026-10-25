// SPDX-License-Identifier: Apache-2.0
import 'dart:math';
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
            (profile['activityIds'] == null ||
                (profile['activityIds'] as List).contains(a.id)) &&
            !disabled.contains(a.id) &&
            a.seconds <= seconds,
      )
      .toList();
}

Activity selectForProfile(
  List<Activity> all,
  Map<String, dynamic> profile,
  int seconds,
  String? previous, {
  Map<String, dynamic>? selectionState,
  Random? random,
}) {
  final fit = fittingActivities(all, profile, seconds);
  if (profile['selection'] == 'fixed') {
    for (final a in fit) {
      if (a.id == profile['favourite']) return a;
    }
  }
  if (profile['selection'] == 'choose' || fit.isEmpty)
    return all.firstWhere((a) => a.id == 'quiet.soft');
  if (profile['selection'] == 'shuffle') {
    final state = selectionState ?? <String, dynamic>{};
    final ids = fit.map((a) => a.id).toSet();
    var seen = (state['seen'] as List? ?? []).whereType<String>().where(ids.contains).toSet();
    var remaining = fit.where((a) => !seen.contains(a.id)).toList();
    if (remaining.isEmpty) {
      seen = <String>{};
      remaining = [...fit];
      if (remaining.length > 1) remaining.removeWhere((a) => a.id == state['last']);
    }
    final chosen = remaining[(random ?? Random()).nextInt(remaining.length)];
    state['seen'] = [...seen, chosen.id];
    state['last'] = chosen.id;
    return chosen;
  }
  final index = fit.indexWhere((a) => a.id == previous);
  return fit[(index + 1) % fit.length];
}

/// Manual browsing is stable as time passes; routine categories constrain
/// automatic suggestions, while explicit exclusions apply to both paths.
List<Activity> browsableActivities(
  List<Activity> all,
  Map<String, dynamic> profile,
) {
  final disabled = ((profile['disabledActivities'] ?? []) as List)
      .cast<String>()
      .toSet();
  return all.where((a) => !disabled.contains(a.id)).toList();
}

List<String> activityExclusions(Activity a, Map<String, dynamic> profile, int seconds) => [
  if (((profile['disabledActivities'] ?? []) as List).contains(a.id)) 'Disabled for this routine',
  if (!((profile['categories'] ?? categories) as List).contains(a.category)) 'Category not selected',
  if (profile['activityIds'] != null && !(profile['activityIds'] as List).contains(a.id)) 'Not in this bundle’s activity list',
  if (a.seconds > seconds) 'Needs a longer break: ${a.seconds}s (current ${seconds}s)',
];

/// Manual choices count as presented, without changing completion/history records.
void notePresented(Activity a, List<Activity> all, Map<String, dynamic> profile,
    int seconds, Map<String, dynamic> state) {
  final ids = fittingActivities(all, profile, seconds).map((a) => a.id).toSet();
  if (!ids.contains(a.id)) return;
  state['last'] = a.id;
  state['seen'] = {
    ...(state['seen'] as List? ?? []).whereType<String>().where(ids.contains),
    a.id,
  }.toList();
}
