# Activity selection

Each routine now keeps its own last eligible activity and shown-activity set.
Rotation remains ordered; Shuffle without repeats randomly picks an unseen eligible
activity until the cycle is exhausted, then starts a new cycle. It avoids repeating
the previous choice at the cycle boundary if there is more than one eligible activity.
One eligible activity necessarily repeats. Empty pools use quiet rest.

Existing modes and published version-1 bundle formats are unchanged. Select
**Shuffle without repeats** in the routine editor to opt in. Existing routines
are not silently switched. The editor lists all available activities and explains
category, bundle-list, disabled and duration exclusions; manual browsing remains
broader than automatic selection.

Progress is stored separately from timer state, survives restart and backup/restore,
and is removed only when its routine is deleted. Manual eligible choices count as
presented, not completed. Changing filters removes ineligible IDs from the current
cycle and admits newly eligible IDs. Historical progress/notes are unaffected.
Legacy global lastActivity is retained for compatibility but no longer drives selection;
each routine starts its own cursor on its first selection after upgrade.

Shuffle is a local app setting. The published bundle v1 protocol deliberately remains
rotation/fixed/choose so older apps can still consume that endpoint. Bundle updates
preserve a local shuffle choice. Old APKs may reject backups containing shuffle;
choose a legacy mode before exporting for an older app.

# Laptop support

Windows, macOS and Linux now have native build targets and a shared desktop-core preview in this PR. Per-routine shuffle and its saved progress work in that adapter too. See [DESKTOP.md](DESKTOP.md) for build instructions, supported features and remaining native integrations.
