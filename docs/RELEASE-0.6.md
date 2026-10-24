# AppBreak 0.6.0 release preparation

Source version: **0.6.0+6**. Target package: `org.appbreak.companion` (FOSS, ARM64, Android 8+).
This is a preparation record, not an announcement of a published release. Do not merge, tag, sign or publish automatically.

## Release notes draft

- Calendar/List day planner and collapsible, filterable participation history with timestamps.
- Live Many Maybes discovery, starter images, navigation and description/alt-text narration. New challenges do not require another APK.
- Versioned, data-only activity content and optional reading/study/screen-use bundles.
- Preview/customise bundles before adding disabled routines. Download missing dependencies directly from the preview without enabling automatic catalogue updates.
- Explicit in-place bundle updates preserve routine IDs, names, reminders, local settings and historical progress. Failed dependency checks do not partially update anything.
- Raster images are cached in private app cache for offline reuse, with alt text/narration and usable text when media is unavailable. SVG challenge fallback remains online.
- Recording/notes, completion/skip tracking, reminders and 18 existing offline activities remain available.

## Compatibility and preparation gates

- [ ] Record the exact release source commit and both successful CI run URLs in the release description.
- [ ] Require passing Content validation and Source checks on the final commit. Source checks now execute native instrumentation on an Android 10 emulator, in addition to JVM tests and the ARM64 release build. Retain emulator XML/log artifacts. Do not call an emulator pass physical-device acceptance.
- [ ] Maintainer reviews content quality, timing, meaningful alt text, source rights and licences.
- [ ] Repository administrator verifies main branch protection: require PR review, code-owner review, stale-approval dismissal, Content validation; restrict direct pushes and bypass. Rulesets were empty and branch-protection reads returned 403 on 2026-10-24. These settings remain unverified with the current integration. Source checks are path-filtered; do not make them an unconditional required check that blocks content-only PRs.
- [ ] After an approved merge, fetch the three main catalogue endpoints listed in CONTENT-PROTOCOL.md; validate JSON and verify legacy endpoint remains compatible. They do not exist on main until this PR merges. Do not point production clients at an unreviewed PR branch to bypass this gate.
- [ ] Complete the physical-device matrix below before publishing.

## Physical-device acceptance matrix (not completed by CI)

Record device/model, Android version, source commit, test date and result for each row. Use a backup stored outside app-private storage before update testing.

| Scenario | Expected result | Evidence |
| --- | --- | --- |
| Update an existing owner-signed 0.5 installation | Installs without uninstall; routines, ideas, recordings and history remain | Pending |
| Install bundle with notifications/usage/overlay permissions denied | Preview works; new routine disabled; no permission prompt until explicit user action | Pending |
| Download dependencies, install, restart in airplane mode | Installed text/activity content works; previously cached raster image works while cache retained | Pending |
| Update bundle after changing interval/name/quiet mode | Same routine ID/history; customisations and reminder state retained | Pending |
| Missing/newer dependency or network failure | Clear failure, no partial routine or destructive changes | Pending |
| Remove bundle routine | Progress/notes remain; current active break cannot be removed | Pending |
| Export/import backup with recordings and installed bundle | Recordings playable; provenance/dependencies/settings restored; no running session restored | Pending |
| TalkBack and 200% text in portrait/landscape | Labels, scrolling and Complete/Skip/Exit controls usable | Pending |
| Native voice in airplane mode; image unavailable | Accurate alt/text narration and understandable no-image pathway | Pending |
| Screen-off cues, silent/DND, Android background restrictions | Existing permission/DND policies respected; no duplicate cues | Pending |
| Recording interrupted by navigation/background | Saved recording stays associated with originating activity | Pending |
| Many Maybes newly added challenge | Discovered remotely, actual image/alt shown, no APK update | Pending |

## Signing and publication handoff

Latest published release checked during preparation: v0.5.0. Reuse the permanent owner certificate recorded in RELEASE-0.4-SIGNING.md; do not generate a new key. The private recovery bundle remains private and was not accessed for this preparation.

1. On the approved final source, build the ARM64 FOSS release using existing untracked owner signing configuration, or sign the matching CI unsigned candidate using that existing key. Never commit `key.properties`, credentials, or a keystore.
2. Run `bash tools/verify_release.sh path/to/appbreak-0.6.0-arm64.apk` with Android build-tools (`apksigner`, `aapt`, `zipalign`) on PATH. It rejects the wrong signer/package/version, checks alignment and prints SHA-256. This script neither signs nor publishes.
3. Verify update installation on the physical device. Keep v0.5 APK and an external backup for recovery; an Android downgrade may require uninstall, so do not promise a lossless binary rollback.
4. Only after the owner authorises release: tag the approved commit, create the GitHub release with these notes plus actual validation evidence, upload the verified signed APK and SHA256SUMS.txt, and verify the public asset/checksum. Do not upload a debug-signed or unsigned review artifact.

No certificate passwords, recovery ZIPs or signing files belong in public artifacts. Public certificate fingerprints are not private keys.
