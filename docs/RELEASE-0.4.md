# AppBreak 0.4.0 test release candidate

Version name 0.4.0, version code 4; Android package org.appbreak.companion.
Target artifact: ARM64 FOSS APK, Android 8 or newer.

## Changes

- Weekly cached, reviewed community activities with offline fallback.
- Notification taps open the relevant break; one permissions checklist.
- Everyday and Advanced settings; default-on popup preference and timed pauses.
- Expired unanswered breaks no longer block later routines; completed/missed
  history and late confirmation are available under Progress.
- Dark break surfaces, portrait/landscape resizing and Expand/Compact controls.
- Offline optional GIF illustrations and a pinned narration/activity toolbar.

## Signing and upgrade gate

The previous 0.3.0 test APK used a temporary test certificate with SHA-256:
476df0a0f9774e562ab7be0da2a3cbfe5fe4071330496cbd5b0203ff8ea93078

The private key is not available in this workspace. The release candidate build
is unsigned and must not be presented as installable. Recover the original key
to preserve update compatibility. A replacement key requires a separately agreed
migration plan; never advise uninstalling before exporting local data.

Physical device acceptance remains outstanding. This is not a store release or
F-Droid submission. No production signing key has been provisioned.

## Verification

GitHub Actions run 39464989552, source commit b1eff80: clean analysis, 58 Flutter
tests, 14 Python tests and both validators pass. ARM64 release APK builds (17.2 MB),
native unit tests pass, and instrumentation APK compiles. Instrumentation tests
have not run on a device. The unsigned candidate is retained as workflow artifact
appbreak-0.4.0-unsigned-arm64 for 14 days.
