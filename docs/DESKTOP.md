# Windows, macOS and Linux preview

The next-release branch includes native Flutter runners for all three laptop platforms. They share the planner (Calendar, Day blocks and List), routine/bundle editor, activity selection including per-routine shuffle without repeats, text ideas and progress views. Android retains its native services.

Desktop uses application-support storage, revision-checked writes and a process lock. New installations use disabled manual routines. No permissions, reminders or automatic triggers are enabled by installing a bundle. Local data and downloaded content remain on that computer; there is no account or cross-device sync.

## Supported in this preview

- Start a manual routine, take/skip/complete a break, and retain local history and notes.
- Create/edit planner blocks, start today's block, extend, mark complete/skip and remove a plan without erasing its historical record.
- Browse/download activities and bundles, preview/customise bundles and install editable local routines. Cached content is usable offline.
- Load Many Maybes challenges remotely; cache bounded image downloads and retain descriptions and text fallbacks.
- Export text using the system save dialog, copy text and export an unencrypted backup in the existing envelope format.

## Limits before a desktop stable release

Keep the app open. Closing its window exits the app; there is no tray/background process or system notification delivery. Elapsed deadlines reconcile on resume/relaunch, but use the system wall clock: changing that clock affects deadlines. A planned block reaching its end is marked ended, never automatically completed. Repeated work/break cycles, scheduled/interval triggers and planner prompt notifications still need desktop scheduling integration.

Active-screen/idle/lock tracking, narration/TTS, recording/playback/dictation, popup windows and backup restore are not implemented on desktop. The app labels the preview and unsupported actions report an explicit error. Android retains these features. Desktop backups contain no audio; Android recordings cannot be imported into desktop in this preview. Native screen-reader and keyboard acceptance testing on each OS remains a release gate.

## Build and verification

Use Flutter 3.35.7 (commit adc901062556672b4138e18a4dc62a4be8f4b3c2) and the committed lockfile. Run `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test` and `flutter build windows`, `flutter build macos` or `flutter build linux` on the corresponding OS. Linux needs Clang, CMake, Ninja, pkg-config, GTK3 and liblzma development packages. Windows needs Visual Studio 2022's C++ desktop workload (the pinned Flutter SDK does not recognise Visual Studio 2026); macOS needs Xcode and CocoaPods.

The desktop workflow builds all three native release targets and retains review artifacts, independently of content-only changes. These are development artifacts, not signed/notarised public installers. Do not distribute as stable until native UI, lifecycle, file dialogs, accessibility, offline and suspend/resume checks pass on each target. CI compilation is not proof of those interactive checks. No APK is published by this workflow.
