import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/timeline_layout.dart';

class DayTimeline extends StatefulWidget {
  final DateTime day;
  final List<Map<String, dynamic>> plans;
  final String Function(Map<String, dynamic>) status;
  final String Function(Map<String, dynamic>) routine;
  final void Function(Map<String, dynamic>) onOpen;
  const DayTimeline({
    super.key,
    required this.day,
    required this.plans,
    required this.status,
    required this.routine,
    required this.onOpen,
  });
  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String time(int minute) {
    final label = TimeOfDay(
      hour: (minute ~/ 60) % 24,
      minute: minute % 60,
    ).format(context);
    return minute >= 1440 ? '$label (+1 day)' : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final ppm = 1.5;
    final minimumHeight = math.max(96.0, scale.scale(14) * 5 + 20);
    final slots = layoutTimeline(
      widget.plans,
      pixelsPerMinute: ppm,
      minimumHeight: minimumHeight,
    );
    final start = slots.isEmpty
        ? 6 * 60
        : math.min(6 * 60, (slots.first.top / ppm / 60).floor() * 60);
    final last = slots.fold<double>(
      22 * 60 * ppm,
      (end, slot) => math.max(end, slot.top + slot.height),
    );
    final end = (last / ppm / 60).ceil() * 60;
    final columns = slots.fold<int>(1, (n, slot) => math.max(n, slot.columns));
    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;
    final showNow =
        DateUtils.isSameDay(now, widget.day) &&
        nowMinute >= start &&
        nowMinute <= end;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tap a block for details and actions. Times show the original plan; short blocks are enlarged for tapping.',
        ),
        if (columns > 1)
          const Text(
            'Overlapping blocks appear side by side. Swipe sideways if needed.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final gutter = math.max(76.0, scale.scale(64));
            final width = math.max(
              constraints.maxWidth,
              gutter + columns * math.max(150.0, scale.scale(110)),
            );
            final height = (end - start) * ppm + 40;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  key: const ValueKey('planner-timeline'),
                  children: [
                    for (var minute = start; minute <= end; minute += 60)
                      Positioned(
                        top: (minute - start) * ppm,
                        left: 0,
                        right: 0,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: gutter,
                              child: Text(
                                time(minute),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            const Expanded(child: Divider(height: 1)),
                          ],
                        ),
                      ),
                    for (final slot in slots)
                      Positioned(
                        top: slot.top - start * ppm,
                        left:
                            gutter +
                            slot.column * (width - gutter) / slot.columns,
                        width: (width - gutter) / slot.columns - 4,
                        height: slot.height - 2,
                        child: block(slot, theme),
                      ),
                    if (showNow)
                      Positioned(
                        top: (nowMinute - start) * ppm,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Semantics(
                            label: 'Current time ${time(nowMinute)}',
                            child: Row(
                              children: [
                                Container(
                                  width: gutter,
                                  color: theme.colorScheme.surface,
                                  child: Text(
                                    'Now',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget block(TimelineSlot slot, ThemeData theme) {
    final p = slot.plan;
    final status = widget.status(p);
    final icon = switch (status) {
      'completed' => Icons.check_circle_outline,
      'active' => Icons.play_circle_outline,
      'skipped' => Icons.skip_next,
      'missed' => Icons.event_busy,
      'delayed' => Icons.snooze,
      _ => Icons.schedule,
    };
    final colors = theme.colorScheme;
    final background = switch (status) {
      'completed' => colors.tertiaryContainer,
      'active' => colors.primaryContainer,
      'missed' => colors.errorContainer,
      _ => colors.secondaryContainer,
    };
    final foreground = switch (status) {
      'completed' => colors.onTertiaryContainer,
      'active' => colors.onPrimaryContainer,
      'missed' => colors.onErrorContainer,
      _ => colors.onSecondaryContainer,
    };
    final times = '${time(p['minute'])} – ${time(p['minute'] + p['minutes'])}';
    final routine = widget.routine(p);
    final label =
        '${p['title']}, $times, ${p['minutes']} minutes, $status. $routine. Tap for details and actions.';
    return Semantics(
      button: true,
      label: label,
      onTap: () => widget.onOpen(p),
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: ValueKey('timeline-${p['id']}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onOpen(p),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: DefaultTextStyle(
                  style: theme.textTheme.bodySmall!.copyWith(color: foreground),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Icon(icon, size: 14, color: foreground),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      ...[
                        Text(
                          times,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          routine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
