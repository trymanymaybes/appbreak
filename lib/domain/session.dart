// SPDX-License-Identifier: Apache-2.0
import 'dart:math';

enum Phase { idle, work, due, rest, paused, finished, pending }

class Moment {
  final int wall, elapsed, boot;
  const Moment(this.wall, this.elapsed, this.boot);
}

/// A running countdown uses elapsedRealtime (includes deep sleep), never ticks.
class Session {
  final String id;
  final String routineId;
  final Phase phase;
  final int wallDue, elapsedDue, boot, remainingMs;
  final String? activity;
  final Phase resumePhase;
  final String timing;
  final Map<String, dynamic> tracking;
  const Session({
    this.id = '',
    this.routineId = '',
    this.timing = 'elapsed',
    this.tracking = const {},
    this.phase = Phase.idle,
    this.wallDue = 0,
    this.elapsedDue = 0,
    this.boot = -1,
    this.remainingMs = 0,
    this.activity,
    this.resumePhase = Phase.work,
  });
  int remaining(Moment now) => phase == Phase.work && timing == 'screen'
      ? (tracking['activeRemaining'] as int? ?? remainingMs)
      : max(
          0,
          boot == now.boot ? elapsedDue - now.elapsed : wallDue - now.wall,
        );
  Session at(Phase next, int duration, Moment now, {String? activityId}) =>
      Session(
        id: id,
        routineId: routineId,
        timing: timing,
        tracking: next == Phase.work && timing == 'screen'
            ? {
                'activeRemaining': duration,
                'activeInterval': tracking['activeInterval'] ?? duration,
                'activeResetMs': tracking['activeResetMs'] ?? 30000,
              }
            : const {},
        phase: next,
        wallDue: now.wall + duration,
        elapsedDue: now.elapsed + duration,
        boot: now.boot,
        activity: activityId ?? activity,
        resumePhase: resumePhase,
      );
  Session reconcile(Moment now) {
    if (![Phase.work, Phase.rest, Phase.paused].contains(phase)) return this;
    // Native usage-event accounting owns active-screen work deadlines.
    if (phase == Phase.work && timing == 'screen') return this;
    // An old work session is abandoned rather than generating a backlog.
    final overdue = boot == now.boot
        ? now.elapsed - elapsedDue
        : now.wall - wallDue;
    if (overdue > 12 * 3600000) return const Session();
    if (remaining(now) > 0) return this;
    if (phase == Phase.paused) {
      // Resume from now, never replay a pause's missed reminder.
      return at(resumePhase, remainingMs, now);
    }
    return at(phase == Phase.work ? Phase.due : Phase.finished, 0, now);
  }

  Session pause(Moment now, int pauseMs) {
    if (![Phase.work, Phase.rest, Phase.due].contains(phase)) {
      throw StateError('Only work or a break can be paused');
    }
    return Session(
      id: id,
      routineId: routineId,
      timing: timing,
      tracking: tracking,
      phase: Phase.paused,
      wallDue: now.wall + pauseMs,
      elapsedDue: now.elapsed + pauseMs,
      boot: now.boot,
      remainingMs: remaining(now),
      activity: activity,
      resumePhase: phase == Phase.due ? Phase.work : phase,
    );
  }

  Session resume(Moment now) {
    if (phase != Phase.paused) throw StateError('Not paused');
    return at(resumePhase, remainingMs, now);
  }

  Map<String, dynamic> toJson() => {
    ...tracking,
    'routineId': routineId,
    'timing': timing,
    'id': id,
    'phase': phase.name,
    'wallDue': wallDue,
    'elapsedDue': elapsedDue,
    'boot': boot,
    'remainingMs': remainingMs,
    'activity': activity,
    'resumePhase': resumePhase.name,
  };
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    routineId: j['routineId'] as String? ?? '',
    timing: j['timing'] as String? ?? 'elapsed',
    tracking: {
      for (final e in j.entries)
        if (e.key.startsWith('active')) e.key: e.value,
    },
    id: j['id'] as String,
    phase: Phase.values.byName(j['phase']),
    wallDue: j['wallDue'] as int,
    elapsedDue: j['elapsedDue'] as int,
    boot: j['boot'] as int,
    remainingMs: j['remainingMs'] as int,
    activity: j['activity'] as String?,
    resumePhase: Phase.values.byName(j['resumePhase']),
  );
}
