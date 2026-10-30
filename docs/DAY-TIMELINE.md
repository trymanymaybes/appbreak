# Day timeline (next release)

My Day now has Month, Day and List views. Tap a date in Month to open its Day
timeline. Existing calendar/list preferences remain valid, and the selected view
is saved locally and included in backups. Existing plans, recurrence, routine
IDs and participation records are unchanged.

Day places blocks at their scheduled start time, with height proportional to
duration. Short blocks have a minimum readable/tappable height. Blocks that
overlap (including enlarged tap areas) share columns; each independent group
can use the full width. Swipe horizontally for dense overlaps. Hour labels,
a current-time line for today, names, routine summaries and status text/icons
support scanning without relying on colour alone. Full labels remain available
to accessibility services and in the details dialog.

Tap a block to open the same Start, Delay, Complete, Extend, Skip, Edit and Delete
controls used by List. The details show delayed reminders and an active session's
end time. Blocks show the original planned schedule: delaying a reminder or
extending an active session does not rewrite the plan. Timelines include plans
starting on the selected date; overnight blocks extend beyond midnight with
`+1 day` labels, rather than appearing twice on two dates.

Break exercises are not separate calendar events. The linked routine controls
breaks when the work session runs. Downloading a bundle does not schedule it.
No drag/resize interactions or changes to reminders/permissions are introduced.

Validation: layout tests cover overlaps, column reuse, independent groups,
minimum tap targets and overnight duration. Widget tests cover overlap geometry,
details/actions, persistence and 200% text on a narrow screen. Native backup tests
cover all three view preferences. Physical-device TalkBack/gesture review remains
part of release acceptance. Older APKs that only accept calendar/list preferences
cannot import a backup containing the new day preference; use Month/List before
exporting a backup intended for those versions.
