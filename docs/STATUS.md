# Current source: 0.4 community catalogue

Verified for 0.4: Flutter analysis clean; 37 Dart/widget tests pass; 14 Python
pack/catalogue tests pass; 9 existing native interval unit tests pass. FOSS debug
APK and instrumentation APK compile successfully using the local pinned toolchain.
Four new catalogue instrumentation tests compile but were not run: no device is
connected. Live network/ETag/cooldown/device acceptance remains outstanding.
This is a source change, not a published production APK.

Repository rulesets API returned an empty list. Legacy branch-protection access
returned HTTP 403, so mandatory-review enforcement is unverified.

See UPDATE-0.4.md. Earlier audit/build records below describe 0.3 and do not establish 0.4 readiness.

# Current version: 0.3

See UPDATE-0.3.md and the versioned 0.3 test logs for current behavior. Older milestone tables below describe the original baseline. Routines, screen-off resets, notification countdown and exit confirmation are now implemented. Hardware acceptance remains outstanding.

# Implementation and verification status

Recorded 2026-10-18. “Implemented” below means source exists and is wired to UI, not that Android hardware behaviour has been verified.

| Area | State | Evidence / remaining work |
| --- | --- | --- |
| Flutter source and UI | Implemented; analyzed | `flutter analyze`: no issues |
| Dart/widget tests | Tested | 27 passed, including 200% text scale |
| Activities | Implemented; validated | 12 original JSON activities, six categories; six Python validator tests pass |
| Session rules | Implemented; unit tested | elapsed time, reboot fallback, pause, stale recovery, no overlaps |
| Native notification actions and reboot receiver | Implemented; compiled | Device testing required |
| Work/break timing, manual break, pause/resume/postpone/skip/cancel | Implemented | 15-minute temporary pause, 5-minute postpone; custom durations |
| Active hours / quiet hours | Implemented; untested on hardware | Whole-hour ranges, local time, discard suppressed reminders |
| Weekday/daily automatic schedules | Deferred | Manual session start in this milestone |
| TTS, speech/language/rate/volume, quiet mode | Implemented; untested on hardware | Offline voice declarations only; airplane-mode engine check outstanding |
| Audio narration pause/resume | Partial | Stop/replay and session pause/resume; replay restarts instructions |
| Local typed ideas | Implemented; failure-path unit test | Native persistence and its test APK compile; device execution pending |
| Recording, playback, rename, deletion/export | Implemented; untested on hardware | Lifecycle, denied mic, audio-focus and storage tests pending |
| Achievements and goal | Implemented; unit tested | First, quiet, movement, exploration, participation-days; daily all-break goal |
| Category-specific custom goals | Deferred | Category milestones exist; editable goal is overall daily count |
| Text and separately selected audio sharing | Implemented; text projection tested | Android grants/share UI pending; container metadata audit pending |
| Idea-card images / multi-badge summary | Deferred | Accessible editable text and single-badge sharing available |
| Backup/restore/delete | Implemented; native tests supplied | Seven native tests compiled; device execution pending; no encryption |
| Private custom packs | Implemented; bundled validator run | Android import and restore of packs pending hardware tests |
| Android APK / release signing | FOSS debug/release and Play debug built | ARM64 release-mode download uses a debug test signature; production key not configured |
| FOSS dependency audit | Partial | Dart licence texts, native resolved graph/POM declarations, signature/permission/native-library checks recorded; full F-Droid review pending |
| Repository | Initial source archive uploaded; normal source push blocked | Connector create-file returned HTTP 403 despite read access. `trymanymaybes/appbreak` is public. |
| Store/F-Droid publication | Not attempted | Hardware, release audit and review gates remain |

## Approval and remaining verification

Explicit approval on 2026-10-18 resolved the earlier SDK and licence gates. Android SDK terms were accepted, Apache-2.0 was applied to original code, and CC-BY-4.0 to original activity content. Flutter runs in its documented CI mode.

1. Execute the seven compiled instrumentation tests and the device checklist on a dedicated Android device. No device or emulator was available in this workspace.
2. Verify offline TTS, reminder timing under battery restrictions, reboot, recording interruptions, sharing grants and recoverable restore on hardware.
3. Replace the archive bootstrap with a normal tracked-source push once repository write access is available. The GitHub connector returned HTTP 403; approved browser upload supplied the archive.
4. Complete release dependency/licence review, owner-controlled signing and F-Droid review. No store submission or approval is claimed.

Deferred product requirements are listed above and in ROADMAP.md; this is a testable pre-alpha, not completion of all original acceptance criteria.

Build evidence: android-debug-build.txt, android-release-build.txt and apk-audit.txt. Release vital lint passed. Compiler deprecation warnings remain; full lint and instrumentation execution are not claimed. The downloadable ARM64 APK targets Android 8+ and has no INTERNET permission.

## 0.2 additions

See UPDATE-0.2.md for the current capability matrix and phone acceptance sequence. It supersedes earlier limitations about active-screen use and absent transcription. Profiles/activity switching are implemented and unit tested. Optional popup launch, Usage access and on-device dictation are implemented but require device verification. Simultaneous transcript + retained audio remains unsupported.

Four native JVM tests now execute the pure screen/lock interval accounting successfully. This does not replace Android instrumentation or hardware tests; those remain unexecuted.
