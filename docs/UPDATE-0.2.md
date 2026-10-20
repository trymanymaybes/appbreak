# AppBreak 0.2 — profiles, outside-app reminders and local dictation

## Implemented

- Three editable break profiles: Short rest, Movement and Creative. Each has its own duration, category and individual-activity filters, rotation/fixed-favourite/choose-at-start selection, and quiet/narration setting. Choose-at-start begins with quiet rest, so the timer never waits for screen interaction.
- Dedicated break player: timer at top, activity and optional participation count in the centre, Type / Speak / explicit audio-recording controls below. Previous, Next, picker and Quiet rest preserve the current deadline and session ID. Activities exceeding remaining time are excluded. Quiet rest remains available for any remaining time.
- Gentle mode by default; opt-in Focus mode hides ordinary skip/finish-early controls. Emergency exit, system navigation and disabling the app remain available.
- Notification permission is requested when starting work; setup shows notification/channel status and has a 10-second inexact test. A new high-importance channel supports heads-up presentation when Android allows it. A denied permission is shown on the dashboard.
- Optional popup launch after explicit Display over other apps access. This uses Android's user-granted background-activity exemption to open a floating break activity; it does not run an overlay service, Accessibility Service or full-screen intent. Notification posts first and remains until the activity becomes visible. Locked/noninteractive screens get notifications only. Actual popup delivery is a device feasibility feature, not a guarantee.
- Elapsed and active-screen timing. Active-screen mode requires Android 9+ and Usage access, counts only interactive AND unlocked intervals, and does not inspect/store app names. Android's usage-event timestamps reconstruct missed intervals. Inexact one-minute alarm requests check progress; Doze/OEM restrictions may delay them substantially. The displayed remaining screen time updates roughly every two seconds while visible; it is not a promised wall-clock reminder time.
- Active-screen mode never silently becomes elapsed mode. Access loss freezes counting. After reboot, a clock discontinuity, or a gap over 12 hours, uncertain time is excluded and shown as a recovery notice. User-selected timing changes apply to the next work session. Work sessions remain explicitly started; there is no continuous daily surveillance or daily auto-start.
- Explicit Android 12+ on-device dictation when the installed service supports it. Partial text, when supplied, is saved locally under one stable note ID; final text replaces that draft. Recognition failures retain recognized text. A one-minute limit, lifecycle exit and audio-focus interruption stop dictation. English (India), Hindi, Kannada and Tamil selections are offered; installed language support is determined by the device, not guaranteed by the menu.
- Typed new-idea drafts are saved after a short debounce and when the app backgrounds; reopening Type restores them. Close without Save retains the draft; Save commits a note and clears it. Existing note edits still require Save.
- Backup validation now checks profile types/ranges/enums and typed-draft size. Existing backup v1 remains compatible; no active session is restored.

## Explicit limitations

- Simultaneous transcription and audio retention is NOT implemented. Android recognizers do not uniformly expose their captured audio. Speak saves text only; Record audio instead is the separate explicit retention flow. There is no automatic network recognizer fallback.
- No photographic imagination cards or new visual activity pack was added; original prompts, quizzes and progress text are available with category icons.
- Popup rendering, Usage access event availability, offline speech/language support, TalkBack, microphone interruptions and device battery policies require phone testing. Unit tests cannot establish these guarantees.
- No screen-off period automatically earns an activity badge. Switching or recording earns nothing by itself. Postponing gives five more minutes in the session's current timing mode and awards no completion.
- Profiles are selected one at a time; this is not a scheduler running three simultaneous break cadences. There are no punitive streaks.

## Phone acceptance sequence

1. Export a backup from the old app, then install the 0.2 APK as an update. Do not uninstall to update; uninstalling deletes private data.
2. Settings → Permissions & reminders → Request notifications. Test reminder, leave the app and observe delivery (allow Android delay). Check notification channel settings if absent.
3. Enable popup access in Android, return and enable the popup switch. Repeat while another app is visible, then with the phone locked. Locked test should produce a notification only.
4. Enable Usage access. Select active-screen timing, start a new work session, use for a minute, lock for a minute, unlock. Remaining active time must exclude the locked period. Repeat with permission revoked, reboot and clock change.
5. Customize each profile, disable an activity, select a fixed favourite, and switch activities mid-break. Confirm deadline does not reset and completion counts once.
6. Speak to text in airplane mode. Check language support, editable note, mic denial, interruption, lock and retry. If unavailable, Type and explicit audio recording remain useful.
7. Type a draft, background/reopen, then save it. Test backup/restore with profile settings and draft on a dedicated device.

## Build and tests

Use README setup, then `flutter test`, `flutter analyze` and `python3 tools/validate_packs.py`.
Native pure accounting tests: `cd android && ./gradlew :app:testFossDebugUnitTest`.
Device persistence tests: `cd android && ./gradlew :app:connectedFossDebugAndroidTest`.
Build: `flutter build apk --release --flavor foss --target-platform android-arm64`.
Release remains unsigned without owner key.properties. The provided download is explicitly test-signed, not store-signed.

Verification recorded: 27 Flutter tests passed, four native JVM accounting tests passed, release vital lint passed, and FOSS release/native test APKs compiled. Seven Android device tests remain unexecuted. See build logs and native-interval-tests.xml.
