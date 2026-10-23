import 'package:flutter_test/flutter_test.dart';
import 'package:appbreak/domain/break_counts.dart';

void main() {
  test(
    'completion wins, duplicate skip is counted once, missed stays separate',
    () {
      final records = breakRecords(
        [
          {'id': 'a', 'category': 'quiet', 'date': '2026-10-23'},
        ],
        [
          {'id': 'a', 'reason': 'skipped', 'date': '2026-10-23'},
          {
            'id': 'b',
            'reason': 'skipped',
            'category': 'movement',
            'date': '2026-10-23',
          },
          {
            'id': 'b',
            'reason': 'skipped',
            'category': 'movement',
            'date': '2026-10-23',
          },
          {
            'id': 'c',
            'reason': 'unconfirmed',
            'category': 'imagination',
            'date': '2026-10-23',
          },
        ],
        [],
      );
      final counts = countByType(records);
      expect(records.length, 3);
      expect(counts['quiet']!['Completed'], 1);
      expect(counts['movement']!['Skipped'], 1);
      expect(counts['imagination']!['Missed'], 1);
      expect(counts['unknown']!['Skipped'], 0);
    },
  );
  test('week uses Monday boundary and excludes future dates', () {
    final records = [
      for (final date in [
        '2026-10-18',
        '2026-10-19',
        '2026-10-23',
        '2026-10-24',
      ])
        <String, dynamic>{'date': date},
    ];
    expect(inPeriod(records, 'This week', DateTime(2026, 10, 23)).length, 2);
    expect(inPeriod(records, 'Today', DateTime(2026, 10, 23)).length, 1);
    expect(inPeriod(records, 'All time', DateTime(2026, 10, 23)).length, 4);
  });
  test('historical category snapshots survive deleted activities', () {
    final records = breakRecords([], [
      {
        'id': 'a',
        'category': 'imagination',
        'activity': 'deleted',
        'reason': 'skipped',
        'date': '2026-10-23',
      },
    ], []);
    expect(records.single['category'], 'imagination');
  });
}
