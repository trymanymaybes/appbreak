import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/timeline_layout.dart';

Map<String, dynamic> plan(String id, int start, int duration) => {
  'id': id,
  'minute': start,
  'minutes': duration,
};
void main() {
  test(
    'overlap clusters share columns; independent blocks regain full width',
    () {
      final slots = layoutTimeline(
        [
          plan('d', 800, 30),
          plan('a', 540, 60),
          plan('b', 570, 60),
          plan('c', 610, 30),
        ],
        pixelsPerMinute: 1,
        minimumHeight: 48,
      );
      expect(slots.map((s) => s.column), [0, 1, 0, 0]);
      expect(slots.map((s) => s.columns), [2, 2, 2, 1]);
      expect(slots.first.top, 540);
      expect(slots.first.height, 60);
    },
  );
  test(
    'short adjacent blocks never cover each other; midnight duration retained',
    () {
      final slots = layoutTimeline(
        [plan('a', 540, 1), plan('b', 542, 1), plan('night', 1430, 60)],
        pixelsPerMinute: 1.5,
        minimumHeight: 64,
      );
      expect(slots[0].height, 64);
      expect(slots[1].column, 1);
      expect(slots.last.top + slots.last.height, 1490 * 1.5);
    },
  );
}
