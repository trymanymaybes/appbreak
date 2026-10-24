# Calendar planner and filterable break history

Development update after 0.5.0, implemented 2026-10-23.

My Day defaults to a month calendar with a selected-day agenda. Calendar/List mode is saved in settings. Month navigation, Today, dated plans and recurring weekday plans share the same selected date and planning actions. A dot marks planned days; screen-reader labels include the full date and plan count.

Progress has a collapsed Past records section. Expand it to filter by activity type or individual activity, then collapse individual date groups. Filters include saved titles for removed activities. Large histories load 50 matching records at a time. Summary totals and achievements are unchanged by history filters.

New completed, skipped and missed outcomes store an epoch timestamp and the local UTC offset, including native notification/background paths. History displays the time in the timezone where it was recorded and sorts same-day outcomes by timestamp. Late confirmation from history preserves the original timestamp and records a separate confirmation time. Old date-only records explicitly show “Time not recorded”; no guessed times are backfilled. Backups preserve and validate these optional fields, and old backups remain supported.

Verification: Flutter analysis is clean and all 73 Flutter tests pass, including calendar navigation/recurrence, 200% text, collapse/filter behavior, local-time formatting, timestamp sorting and late confirmation. Android FOSS debug APK and instrumentation APK compile; 15 native JVM tests pass. New instrumentation cases cover timestamp archiving and backup round-trip/validation, but cannot run here without an Android device.

This source update is not included in the published 0.5.0 APK.
