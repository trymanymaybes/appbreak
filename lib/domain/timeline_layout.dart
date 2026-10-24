import 'dart:math' as math;

/// Positions include a minimum visual height, so even adjacent short plans
/// cannot obscure each other's tap targets. Input order is not mutated.
class TimelineSlot {
  final Map<String, dynamic> plan;
  final double top, height;
  final int column;
  int columns = 1;
  TimelineSlot(this.plan, this.top, this.height, this.column);
}

List<TimelineSlot> layoutTimeline(
  List<Map<String, dynamic>> plans, {
  required double pixelsPerMinute,
  required double minimumHeight,
}) {
  final ordered = [...plans]
    ..sort((a, b) {
      final byTime = (a['minute'] as int).compareTo(b['minute'] as int);
      return byTime != 0 ? byTime : (a['id'] as String).compareTo(b['id']);
    });
  final result = <TimelineSlot>[];
  var group = <TimelineSlot>[];
  final ends = <double>[];
  var groupEnd = -1.0;
  void finishGroup() {
    for (final slot in group) {
      slot.columns = ends.length;
    }
    group = [];
    ends.clear();
  }

  for (final plan in ordered) {
    final top = (plan['minute'] as int) * pixelsPerMinute;
    // Cross-midnight plans retain their full duration on the starting day.
    final height = math.max(
      (plan['minutes'] as int) * pixelsPerMinute,
      minimumHeight,
    );
    if (top >= groupEnd) finishGroup();
    var column = ends.indexWhere((end) => end <= top);
    if (column < 0) {
      column = ends.length;
      ends.add(top + height);
    } else {
      ends[column] = top + height;
    }
    groupEnd = math.max(group.isEmpty ? -1 : groupEnd, top + height);
    final slot = TimelineSlot(plan, top, height, column);
    group.add(slot);
    result.add(slot);
  }
  finishGroup();
  return result;
}
