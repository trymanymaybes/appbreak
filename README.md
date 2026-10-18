# AppBreak — Smart Break & Activity Companion

Android-first, local-first Flutter implementation. A separate product and source tree; no Many Maybes branding, infrastructure, account, content or repository is reused.

**Status: Android pre-alpha build; device acceptance remains outstanding.** Flutter analysis, 34 Dart/widget tests and six Python pack-validator tests pass. FOSS release and native instrumentation APKs compile successfully; nine native interval-accounting unit tests pass. An ARM64 release-mode APK is available with a debug test signature; its compiled manifest has no Internet permission. Android SDK terms and Apache-2.0 / CC-BY-4.0 licences were explicitly approved on 2026-10-18. No device tests or store publication are claimed. Source repository: https://github.com/trymanymaybes/appbreak. Read `docs/STATUS.md` before evaluating readiness.

## Version 0.3 update

See `docs/UPDATE-0.3.md` for the Routines page: automatic screen-use, manual sessions, repeating intervals and scheduled daily reminders; per-routine activities, goals, colours and notification channels; screen-off resets; break-notification countdown; and Yes/Skip confirmation after emergency exit or Android Back. Screen rest is enabled by default after migration but needs Usage access. Popups require system overlay permission. Device acceptance is still outstanding.

## Version 0.2 update

See `docs/UPDATE-0.2.md` for break profiles and activity switching, optional popup launch, permission setup/test notification, active-screen timing and offline dictation. Popup, usage-event availability and speech/language support are explicitly device-dependent. Speak saves text; retaining audio is a separate explicit recording action. Install the new test APK as an update to preserve notes.

## Repository bootstrap

The initial browser upload contains this README and `appbreak-source.zip`. Extract the archive to obtain the complete project tree, documentation, tests and build scripts. A normal tracked-source push is pending GitHub connector write access; its create-file request returned HTTP 403 for this new repository.

## First runnable milestone

Configure a work interval in Settings → enable notification permission → Start work session → receive a local reminder or enter the break while the app is visible → quiet rest (or select an installed offline voice and press Play) → optionally capture an idea → confirm participation → inspect local progress. Automatic routines repeat; manually started routines can repeat or stop after one session. A user-confirmed completion is never represented as verified eye rest, movement or hydration.

## Layout

| Path | Responsibility |
| --- | --- |
| `lib/domain` | Pure Dart session clock/state rules, activity selection, achievements, sharing projections |
| `lib/application/controller.dart` | Serialized operations, lifecycle reconciliation, application state using ChangeNotifier |
| `lib/platform/device.dart` | Replaceable Android method-channel adapter; fake adapter used by tests |
| `lib/ui` | Material screens, labelled controls, text scaling, share/restore confirmations |
| `android/app/src/main/kotlin/org/appbreak/companion` | SQLite, AlarmManager, TTS, recording, SAF file pickers and sharing |
| `assets/activities.json` | Twelve original inert offline activities |
| `schemas/activity-pack.schema.json` | Versioned community pack schema |
| `tools/validate_packs.py` | Dependency-free pack validator |
| `test` | Domain, persistence-failure and large-text UI tests |
| `android/app/src/androidTest` | Device tests for persistence and backups, not executed here |
| `docs` | Architecture, privacy, capability matrix, release gates, device checklist and roadmap |

ChangeNotifier is deliberately used instead of adding Riverpod to a five-section app. Domain rules are independent of Flutter. Android adapters use platform APIs rather than third-party Flutter plugins. The native receiver has a small mirrored recovery rule set because it must run without starting a Dart engine; parity tests on devices remain a release gate.

## Setup and commands

Baseline actually used for Dart checks: Flutter **3.35.7**, Dart **3.9.2**, Flutter commit `adc901062556672b4138e18a4dc62a4be8f4b3c2`. This is a pinned baseline, NOT a claim that it is current stable. Upgrade validation against the current stable Flutter is a release gate.

Android configuration: Java 17, SDK 36, min API 26, AGP 8.11.1, Gradle 8.13, Kotlin 2.1.0; these native versions compiled successfully together. Install Flutter and Android command-line tools from their official distributions. Review and accept Android SDK terms for your own build environment.

```bash
export PATH="/path/to/flutter/bin:/path/to/android-sdk/cmdline-tools/latest/bin:$PATH"
export ANDROID_HOME=/path/to/android-sdk
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
sdkmanager --licenses
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;35.0.0' 'ndk;27.0.12077973'
flutter doctor -v
flutter pub get --enforce-lockfile
python3 tools/validate_packs.py
flutter analyze
flutter test --reporter expanded
flutter run --flavor foss
flutter build apk --debug --flavor foss
```

The SDK's normal CI mode avoids its Azure instance-metadata autodetection. On container filesystems that reject tar ownership changes, additionally set `TAR_OPTIONS=--no-same-owner` during SDK bootstrapping. Core application runtime has no Internet permission; initial build tooling downloads dependencies.

Device instrumentation, after installing the SDK and connecting a dedicated test device:

```bash
cd android
./gradlew :app:connectedFossDebugAndroidTest
cd ..
```

Release/signing instructions, including the owner-controlled signing key and F-Droid gates, are in `docs/RELEASE.md`. Do not distribute a debug-signed build as a release.

## Licensing

Original application source is **Apache-2.0** (root `LICENSE`). Original bundled activities are **CC-BY-4.0** (`assets/LICENSE-CC-BY-4.0.txt`). Owner approval was received on 2026-10-18. Third-party SDK/template/dependency notices retain their own licences under `third_party/licenses`. See `NOTICE` for scope. F-Droid inclusion still requires native artifact/dependency review and successful device testing.
