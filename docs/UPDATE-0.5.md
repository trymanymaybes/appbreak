# AppBreak 0.5: planner, outcomes and look-away cues

Implemented locally on 2026-10-23. This document describes source behavior; release and device acceptance are tracked in STATUS.md.

- My Day plans dated or repeating activity blocks, associates a break routine, reminds the user, and requires explicit Start. Blocks can be delayed, extended, completed or skipped. Only one session runs at a time.
- Progress counts Completed, Skipped and Missed separately by activity category for Today, This week (Monday start) and All time. Session IDs deduplicate outcomes, completion overrides stale copies, and only completed breaks earn achievements. New records retain category/title even if an activity is removed.
- Break notifications show today's skipped count, including the current category when known. Skipping also updates a quiet summary notification that opens Progress.
- Break views and popup windows have a pinned Complete / Skip / Postpone row above scrolling instructions. Postpone delays for five elapsed minutes without completion or skip credit. Emergency exit remains separate. Status includes a colored dot and text.
- Start/end cues have independent sound and vibration settings and previews. End uses two pulses; start uses one. Android silent/Do Not Disturb policies are respected. Durable event keys prevent repeats after rotation/reopening; a process kill between saving an event and playing it may omit a cue.
- Six Many Maybes imagination adaptations work offline, with optional external challenge, YouTube and Instagram links. Specific video links are available for challenges 01 and 03; other challenges link to the channels. Some external videos may require account access or be private.
- Prompts invite recording or dictating an idea. Saved ideas retain their originating challenge. Submit this idea lets the user review a written summary, save it as a PNG idea card, and open the matching website submission form. The website accepts images; raw audio remains local. Signing in, selecting the card and explicitly submitting on the website are still required.
- English voice setup opens the Android speech engine's data installer, refreshes installed voices after return, selects an available offline English voice (preferring en-IN), and offers a test. Installation remains controlled by the Android engine/user; the app cannot silently install system voices.

## Verification

Flutter analysis and all 68 Flutter tests pass, including outcome deduplication, category snapshots, date filters, postponement, saved-idea attribution and popup actions at 200% text scale in portrait/landscape. Both activity/content validators and all 14 Python tests pass. The FOSS ARM64 debug APK and instrumentation APK compile; all 15 native JVM tests pass. Instrumentation tests were not executed. The debug APK is not an owner-signed upgrade release.

Physical-device acceptance still needs: start/end cues with the screen off; silent/DND and vibration hardware; notification permission and background restrictions; English voice download/airplane-mode playback; recording interruptions; PNG export and website submission; planner reminders across midnight, reboot and timezone changes. No device or hardware-accelerated emulator is available here.
