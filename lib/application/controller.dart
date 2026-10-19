// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/activity.dart';
import '../domain/session.dart';
import '../domain/profile.dart';
import '../platform/device.dart';

class Companion extends ChangeNotifier {
  final Device device;
  Companion(this.device);
  Map<String, dynamic> data = {};
  List<Activity> activities = [];
  List<Activity> bundled = [];
  List<Activity> catalog = [];
  bool catalogEnabled = true, catalogBusy = false;
  bool disposed = false;
  String catalogStatus = 'Built-in activities available offline.';
  void readCatalog(String? value) {
    if (value == null) return;
    final snapshot = jsonDecode(value) as Map;
    catalog = (snapshot['activities'] as List)
        .map((a) => Activity(Map<String, dynamic>.from(a)))
        .toList();
    catalogEnabled = snapshot['enabled'] == true;
    catalogStatus = snapshot['status'] as String;
  }

  Future<void> refreshCatalog({bool manual = false}) async {
    if (catalogBusy || !visible || session.phase != Phase.idle) return;
    catalogBusy = true;
    try {
      final result = await device.call<String>('catalogRefresh', {
        'manual': manual,
      });
      if (disposed) return;
      readCatalog(result);
      await refresh();
    } catch (_) {
      catalogStatus =
          'Catalogue unavailable. Existing activities remain available.';
    } finally {
      catalogBusy = false;
      if (!disposed) notifyListeners();
    }
  }

  Future<void> setCatalogEnabled(bool enabled) async {
    readCatalog(
      await device.call<String>('catalogEnabled', {'enabled': enabled}),
    );
    notifyListeners();
    if (enabled) await refreshCatalog();
  }

  Session session = const Session();
  Moment moment = const Moment(0, 0, 0);
  int breakNavigationVersion = 0;
  String? error;
  bool busy = false, visible = true;
  Timer? ticker;
  Map<String, dynamic> get settings =>
      Map<String, dynamic>.from(data['settings'] ?? {});
  List<dynamic> get history => data['history'] ?? [];
  List<dynamic> get missedBreaks => data['missedBreaks'] ?? [];
  List<Map<String, dynamic>> get breakRecords => [
    ...history.map((h) => <String, dynamic>{...h, 'status': 'Completed'}),
    ...missedBreaks.map((h) => <String, dynamic>{...h, 'status': 'Missed'}),
  ]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

  void archiveBreak(String reason) {
    if (![Phase.rest, Phase.finished, Phase.pending].contains(session.phase))
      return;
    data['missedBreaks'] = [
      ...missedBreaks.where((h) => h['id'] != session.id),
      {
        ...session.toJson(),
        'reason': reason,
        'date': DateTime.fromMillisecondsSinceEpoch(
          moment.wall,
        ).toIso8601String().substring(0, 10),
      },
    ];
  }

  Future<void> confirmArchivedBreak(String id) => act(() async {
    final record = missedBreaks.where((h) => h['id'] == id).firstOrNull;
    if (record == null) return;
    final activity = activities
        .where((a) => a.id == record['activity'])
        .firstOrNull;
    if (!history.any((h) => h['id'] == id)) {
      data['history'] = [
        ...history,
        {
          'id': id,
          'routine': record['routineId'] ?? '',
          'activity': record['activity'],
          'category': activity?.category ?? 'quiet',
          'date': record['date'],
          'selfReported': true,
        },
      ];
    }
    data['missedBreaks'] = missedBreaks.where((h) => h['id'] != id).toList();
    // Historical confirmation never changes the currently running timer.
    if (session.id == id) session = const Session();
  });

  List<dynamic> get ideas => data['ideas'] ?? [];
  int get workSeconds =>
      profile['workSeconds'] ?? settings['workSeconds'] ?? 1500;
  List<Map<String, dynamic>> get profiles =>
      ((settings['profiles'] ?? defaultProfiles) as List)
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
  Map<String, dynamic> get profile =>
      profiles
          .where(
            (p) =>
                p['id'] ==
                (session.routineId.isEmpty
                    ? settings['profile']
                    : session.routineId),
          )
          .firstOrNull ??
      profiles.first;
  int get breakSeconds =>
      profile['breakSeconds'] ?? settings['breakSeconds'] ?? 60;
  List<Activity> get alternatives => browsableActivities(activities, profile);
  Future<void> updateProfile(Map<String, dynamic> changes) =>
      saveRoutine({...profile, ...changes});
  Future<void> saveRoutine(Map<String, dynamic> routine) => act(() async {
    final list = profiles;
    final i = list.indexWhere((p) => p['id'] == routine['id']);
    if (i < 0) {
      if (list.length >= 20) throw StateError('At most 20 routines');
      list.add(routine);
    } else {
      list[i] = routine;
    }
    data['settings'] = {...settings, 'profiles': list};
    if (session.routineId != routine['id'] || session.phase == Phase.idle)
      (data['routineState'] as Map?)?.remove(routine['id']);
  });
  Future<void> deleteRoutine(String id) => act(() async {
    if (session.routineId == id && session.phase != Phase.idle)
      throw StateError('Finish or skip this routine’s current break first.');
    final list = profiles.where((p) => p['id'] != id).toList();
    if (list.isEmpty)
      throw StateError('Keep at least one routine. You can disable it.');
    data['settings'] = {
      ...settings,
      'profiles': list,
      'profile': list.first['id'],
    };
    (data['routineState'] as Map?)?.remove(id);
  });
  Future<void> startRoutine(String id) async {
    await device.call('startRoutine', {'id': id});
    await refresh();
  }

  Future<void> leaveBreak() async {
    await act(() async {
      if (![Phase.rest, Phase.finished].contains(session.phase) &&
          !(session.phase == Phase.paused && session.resumePhase == Phase.rest))
        return;
      // Preserve the remaining countdown when leaving an unfinished break.
      session = session.at(
        Phase.pending,
        session.phase == Phase.paused
            ? session.remainingMs
            : session.remaining(moment),
        moment,
      );
      await device.call('stopAudio');
    });
    if (error == null) await device.call('closePopup');
  }

  Future<void> switchActivity(String id) => act(() async {
    if (session.phase != Phase.rest) return;
    final a = activities.firstWhere((a) => a.id == id);
    if (id != 'quiet.soft' && !alternatives.any((x) => x.id == id))
      throw StateError('This activity is disabled for this routine.');
    await device.call('stopSpeech');
    session = session.at(
      Phase.rest,
      session.remaining(moment),
      moment,
      activityId: a.id,
    );
    data['lastActivity'] = id;
  });
  Future<void> cycleActivity(int direction) async {
    final fit = alternatives;
    if (fit.isEmpty) return switchActivity('quiet.soft');
    final i = fit.indexWhere((a) => a.id == session.activity);
    await switchActivity(fit[(i + direction) % fit.length].id);
  }

  Activity? get current =>
      activities.where((a) => a.id == session.activity).firstOrNull;
  Future<void> init() async {
    final pack = jsonDecode(
      await rootBundle.loadString('assets/activities.json'),
    );
    activities = (pack['activities'] as List).map((a) => Activity(a)).toList();
    bundled = [...activities];
    try {
      readCatalog(await device.call<String>('catalogLoad'));
    } catch (_) {}
    await refresh();
    unawaited(refreshCatalog());
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (visible) refresh();
    });
  }

  Future<void> refresh() async {
    if (busy) return;
    busy = true;
    try {
      data = await device.load();
      final previous = current;
      final localIds = {
        ...bundled.map((a) => a.id),
        ...((data['customActivities'] ?? []) as List).map((a) => a['id']),
      };
      activities = [
        ...bundled,
        ...catalog.where((a) => !localIds.contains(a.id)),
        ...((data['customActivities'] ?? []) as List).map(
          (a) => Activity(Map<String, dynamic>.from(a)),
        ),
      ];
      // An update must not replace the instructions in an ongoing break.
      if (previous != null && session.phase != Phase.idle) {
        activities.removeWhere((a) => a.id == previous.id);
        activities.add(previous);
      }
      if (!(data['settings'] as Map? ?? {}).containsKey('profiles')) {
        data['settings'] = {
          ...settings,
          'profiles': settings['autoSetup'] == false
              ? defaultProfiles.map((p) => {...p, 'enabled': false}).toList()
              : defaultProfiles,
        };
        await device.save(data);
        data['revision'] = (data['revision'] ?? 0) + 1;
      }
      if (settings['routinesVersion'] != 1) {
        final migrated = profiles
            .asMap()
            .entries
            .map(
              (e) => {
                'trigger': e.key == 0 ? 'screen' : 'manual',
                'enabled': e.key == 0,
                'workSeconds': workSeconds,
                'resetSeconds': 30,
                'popup': true,
                ...e.value,
              },
            )
            .toList();
        data['settings'] = {
          ...settings,
          'profiles': migrated,
          'routinesVersion': 1,
        };
        await device.save(data);
        data['revision'] = (data['revision'] ?? 0) + 1;
      }
      moment = await device.now();
      session = data['session'] == null
          ? const Session()
          : Session.fromJson(Map<String, dynamic>.from(data['session']));
      final open = await device.call<Map>('consumeBreakOpen');
      final requestedId = open?['sessionId'];
      final openCurrentBreak =
          open != null &&
          (requestedId == null || requestedId == session.id) &&
          [
            Phase.due,
            Phase.rest,
            Phase.finished,
            Phase.pending,
            Phase.paused,
          ].contains(session.phase);
      final next = session.reconcile(moment);
      if (next.phase != session.phase) {
        session = next;
        if (session.phase == Phase.finished) {
          await device.call('stopSpeech');
          await device.call('cue', {'enabled': settings['cues'] == true});
        }
        await persist();
      }
      if (session.phase == Phase.due && visible) {
        if (openCurrentBreak || await device.call<bool>('allowed') != false) {
          await _breakNow();
        } else {
          session = const Session();
        }
        await persist();
      }
      if (openCurrentBreak) breakNavigationVersion++;
      error = null;
    } catch (e) {
      error = '$e';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> persist() async {
    data['schemaVersion'] = 1;
    data['session'] = session.toJson();
    await device.save(data);
    data['revision'] = (data['revision'] ?? 0) + 1;
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    try {
      data = await device.load();
      moment = await device.now();
      session = data['session'] == null
          ? const Session()
          : Session.fromJson(Map<String, dynamic>.from(data['session']));
      await action();
      await persist();
      error = null;
    } catch (e) {
      error = '$e';
    }
    busy = false;
    notifyListeners();
  }

  String newId() => '${moment.wall}-${moment.elapsed}';
  Future<void> start() => act(() async {
    if (![Phase.idle, Phase.finished].contains(session.phase))
      throw StateError('Cancel the current session first');
    await device.call('notifications');
    final timing = settings['timing'] ?? 'elapsed';
    if (timing == 'screen') {
      final status = await device.call<Map>('capabilities');
      if (status?['usage'] != true)
        throw StateError(
          'Enable Usage access in Settings for active-screen timing.',
        );
    }
    archiveBreak('unconfirmed');
    session = Session(
      id: newId(),
      timing: timing,
    ).at(Phase.work, workSeconds * 1000, moment);
  });
  Future<void> _breakNow() async {
    final activity = selectForProfile(
      activities,
      profile,
      breakSeconds,
      data['lastActivity'],
    );
    session = Session(
      id: newId(),
      routineId: session.routineId,
    ).at(Phase.rest, breakSeconds * 1000, moment, activityId: activity.id);
    data['lastActivity'] = activity.id;
    // Instructions are opt-in via Play: TalkBack never competes with auto speech.
    await device.call('cue', {'enabled': settings['cues'] == true});
  }

  Future<void> breakNow() => act(_breakNow);
  Future<void> pause() => act(() async {
    session = session.pause(moment, 15 * 60000);
    await device.call('stopSpeech');
  });
  Future<void> resume() => act(() async {
    session = session.resume(moment);
  });
  Future<void> postpone() => act(() async {
    if (![
      Phase.work,
      Phase.due,
      Phase.rest,
      Phase.finished,
    ].contains(session.phase))
      throw StateError('No session');
    session = Session(
      id: newId(),
      timing: session.timing,
      routineId: session.routineId,
    ).at(Phase.work, 5 * 60000, moment);
    await device.call('stopSpeech');
  });
  Future<void> cancel() async {
    await act(() async {
      archiveBreak('skipped');
      session = const Session();
      await device.call('stopSpeech');
    });
    if (error == null) await device.call('closePopup');
  }

  Future<void> complete() => act(() async {
    if (![Phase.rest, Phase.finished, Phase.pending].contains(session.phase))
      return;
    final a = current;
    if (a == null) return;
    final h = [...history];
    if (!h.any((x) => x['id'] == session.id)) {
      h.add({
        'id': session.id,
        'routine': session.routineId,
        'activity': a.id,
        'category': a.category,
        'date': DateTime.fromMillisecondsSinceEpoch(
          moment.wall,
        ).toIso8601String().substring(0, 10),
        'selfReported': true,
      });
    }
    data['history'] = h;
    data['missedBreaks'] = missedBreaks
        .where((h) => h['id'] != session.id)
        .toList();
    session = const Session();
    await device.call('stopSpeech');
  });
  Future<void> importPack() async {
    final json = await device.call<String>('importPack');
    if (json == null) return;
    final pack = jsonDecode(json);
    final imported = (pack['activities'] as List)
        .map((a) => Activity(a))
        .toList();
    await act(() async {
      if (imported.any((a) => bundled.any((b) => b.id == a.id)))
        throw StateError('Custom IDs must not replace bundled activities');
      final existing = {
        for (final a in ((data['customActivities'] ?? []) as List)) a['id']: a,
      };
      for (final a in imported) {
        existing[a.id] = a.data;
      }
      if (existing.length > 200)
        throw StateError('At most 200 private custom activities');
      data['customActivities'] = existing.values.toList();
    });
    await refresh();
  }

  int get popupPauseRemainingMs {
    final until = settings['popupPausedUntil'] as int? ?? 0;
    return (until - moment.wall).clamp(0, 24 * 60 * 60 * 1000).toInt();
  }

  Future<void> setPopups(bool enabled) =>
      updateSettings({'popup': enabled, 'popupPausedUntil': 0});
  Future<void> pausePopups(int minutes) => act(() async {
    if (![15, 60, 120].contains(minutes))
      throw ArgumentError('Unsupported popup pause');
    data['settings'] = {
      ...settings,
      'popup': true,
      'popupPausedUntil': moment.wall + minutes * 60000,
    };
  });

  Future<void> updateSettings(Map<String, dynamic> value) => act(() async {
    data['settings'] = {...settings, ...value};
  });
  Future<void> saveIdea(
    String text, {
    String? id,
    String? recording,
    String? title,
  }) => act(() async {
    final list = [...ideas];
    final index = list.indexWhere((x) => x['id'] == id);
    final note = {
      'id': id ?? newId(),
      'title': title ?? 'Idea',
      'text': text,
      'recording': recording,
      'activity': session.activity,
      'session': session.id,
    };
    if (index < 0) {
      list.add(note);
    } else {
      list[index] = {...Map<String, dynamic>.from(list[index]), ...note};
    }
    data['ideas'] = list;
  });
  Future<void> deleteIdea(String id) => act(() async {
    final note = ideas.firstWhere((x) => x['id'] == id);
    data['ideas'] = ideas.where((x) => x['id'] != id).toList();
    // File deletion follows committed metadata through native garbage collection.
    if (note['recording'] != null) data['pendingDelete'] = note['recording'];
  });
  Future<void> narrate() async {
    try {
      if ((profile['quiet'] ?? settings['quiet'] ?? true) == true) return;
      await device.call('speak', {
        'steps': current?.steps ?? [],
        'language': current?.data['language'] ?? 'en-IN',
        'voice': settings['voice'],
        'rate': settings['rate'] ?? 1.0,
        'volume': settings['volume'] ?? 0.8,
      });
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    ticker?.cancel();
    super.dispose();
  }
}
