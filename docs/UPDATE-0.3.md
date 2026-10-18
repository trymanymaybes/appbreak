# AppBreak 0.3 — independent routines

## What changed

The Routines page supports up to 20 separately enabled task/lifestyle routines. Existing activity profiles migrate without losing their activity choices. The first profile defaults to automatic active-screen timing; existing notification/overlay permission decisions are respected. Usage access must be granted before Android can measure screen intervals. No package names are retained.

Triggers: accumulated interactive, unlocked screen time; manually started elapsed work sessions; automatic elapsed intervals; daily local times on selected weekdays. Each routine has active hours, break duration, included categories, excluded activities, favourite/rotation/choose-at-start, quiet narration, notification toggle, popup toggle, reminder text, four readable colour accents, and optional daily/weekly goal. For several times per day, create separate routines. Same start/end hour means all day. Global quiet hours override routines.

Sound, vibration, heads-up behaviour and lock-screen visibility are controlled using each routine's **Sound & vibration** button, which opens its own Android notification channel settings. Android owns the notification background/template and may ignore accent colours. Reusing a channel never overwrites the user's sound/importance choices. No new runtime dependencies were added; VIBRATE is the only added manifest permission.

## Counter and participation rules

- Screen-off for 30 seconds resets screen accumulation by default. A routine may use another threshold or its full break duration. Shorter interruptions pause accumulation. Locked but still illuminated time is excluded from counting but is not a screen-off reset.
- Reset is derived from timestamped usage events, including intervals spanning multiple checks. It awards no completion or badge.
- Completing any break also resets all enabled active-screen routine counters. Complete or Skip resets the originating routine. Automatic intervals repeat. Manual routines may repeat or end after one break.
- During the routine's break, its work counter is suspended. Other routine counters continue. One break presentation/confirmation slot prevents overlapping popups. Other due routines are deferred, and overdue requests older than 15 minutes are discarded instead of replaying a backlog.
- Exit via Emergency exit or Android Back preserves an unconfirmed break. A notification asks **Did you take your break?**, with Yes, I did / Skip. Yes is explicit self-reported participation and is deduplicated by session ID. Skip awards nothing. A pending confirmation also remains on Today. The confirmation must be resolved before another break screen is presented.
- Swiping away a notification earns no credit and suppresses reposting for that session phase; pending confirmation remains on Today.
- Timer expiration never awards participation. The running break notification uses Android's countdown chronometer; the system may visually vary its presentation. A waiting reminder has no countdown until the break starts.
- Per-routine goals count confirmed sessions associated with that routine; weekly goals use local Monday–Sunday. Existing historical sessions without routine attribution retain achievements but are not retrospectively assigned to goals.

## Delivery and recovery

Background checks request inexact alarms, usually at least a minute apart. Doze, battery restrictions, force-stop, OS/OEM policies and revoked permissions can delay or prevent delivery. No exact alarms, foreground service, full-screen intents, silent audio or accessibility service is used. Popups default on at routine level, require Android overlay permission, and respect the global popup switch. Locked devices receive notifications only. Notification disablement is respected, including the follow-up; Today retains confirmation.

A daily scheduled reminder has a 15-minute delivery grace period, no yesterday backlog, and one occurrence per local date. Outside permitted days/hours, work accumulation starts fresh. A reboot or clock discontinuity excludes uncertain screen intervals; elapsed running work uses monotonic time on the same boot. Intervals over 12 hours overdue restart fresh. Restore discards runtime cursors/active sessions, preserves routine configuration and deduplicated history, and initializes enabled automatic routines fresh.

## Installation and validation

Install the ARM64 0.3 test APK over 0.2 without uninstalling. It uses the same debug test certificate, not a production signing key. Make a manual backup before testing an upgrade. Android 8+ can run the app; screen-use events require Android 9+; on-device dictation requires a suitable Android 12+ local recognition service/model.

See the version-specific test and build logs alongside this document for actual results. Hardware testing is outstanding: overlay display, notification actions/countdown rendering and sound, UsageStats events on the user's phone, battery restrictions, reboot, lock, speech models and TalkBack.

## Phone acceptance checklist

1. Upgrade without uninstalling; verify old notes, recordings and activity preferences.
2. Enable Usage access and notifications. Enable overlay access only if popups are wanted. Test a two-minute screen routine with a 30-second break.
3. Accumulate one minute; lock for 10 seconds, unlock: counter resumes. Lock for 35 seconds: counter restarts with no new goal credit. Repeat using full-break reset duration.
4. Add a manual routine and a scheduled routine for a few minutes ahead. Verify separate activities, goals, channels, sound settings and disabled days.
5. Background the app; observe delayed delivery if battery restricted. Verify locked devices never open the popup.
6. Start a break, check notification countdown. Emergency exit and Android Back must retain Yes/Skip; Yes credits exactly once and Skip never credits. Disable notification permission and verify Today still asks.
7. Trigger two routines together: only one screen; the other waits or expires after the grace window.
8. Verify airplane-mode operation, 200% text, TalkBack focus, screen-off reset across polls, reboot/time/time-zone changes and restore with enabled routines.

## Official references checked 2026-10-18

- https://developer.android.com/develop/ui/views/notifications/channels — user ownership of channel sounds and importance.
- https://developer.android.com/reference/android/app/Notification.Builder — countdown chronometers.
- https://developer.android.com/guide/components/activities/background-starts — background launch restrictions and overlay permission exemption.

## Verification performed for 0.3

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 34 tests passed, including large-text Routines/editor and pending confirmation tests.
- `:app:testFossDebugUnitTest`: 9 pure Kotlin screen-interval tests passed, covering short/long screen-off, threshold boundary, cross-poll intervals and locked-screen behavior.
- `:app:assembleFossRelease` and `:app:assembleFossDebugAndroidTest`: compiled successfully. Nine Android instrumentation tests are compiled but **not executed**; `adb devices` lists no devices.
- `python3 tools/validate_packs.py`: 12 valid offline activities.
- The shipped APK is ARM64, version 0.3.0 (3), release-mode code with a debug test signature. Signature/manifest evidence is in `apk-0.3-audit.txt`.
- No claim of hardware acceptance, F-Droid approval, production signing or store publication.
