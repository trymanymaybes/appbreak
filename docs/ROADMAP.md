# Phased roadmap

## Phase 0: prove the Android milestone

SDK terms, repository creation, owner licences and initial native compilation are complete. Resolve remaining compiler/lint warnings and tracked-source repository delivery. Run instrumentation and airplane-mode device checklist. Inspect audio metadata and URI permissions. Validate current stable Flutter before distribution. No premium work precedes a useful, tested FOSS release.

## Phase 1: complete Android convenience features

Optional weekday/daily schedule with next-window preview, configurable pause/postpone durations, editable category goals, activity replacement picker, precise narration pause/resume, better incomplete-recording recovery and orphan cleanup, multi-badge summaries and optional local idea-card images. Keep quiet rest primary and offer all basic accessibility for free. Implement SQL tables/paging if the atomic-document approach becomes too large. Add current-state widget and more granular storage deletion only if useful.

Overlay feasibility is a separate opt-in experiment: test SYSTEM_ALERT_WINDOW permission lifecycle, vendor behaviour and always-reachable dismiss/emergency controls. Notifications remain the fallback. Do not use Accessibility Services, forced full-screen intents, silent audio or unsupported foreground services.

## Phase 2: optional premium editions

Curated licensed packs, richer local scheduling, themes and platform-specific conveniences. Add billing only in the Play flavor/source graph after policy review and license audit. Entitlements must not lock users out of their existing notes/backups or baseline accessibility. No accounts/analytics/mandatory service. Additional packs use the same validated inert schema; optional catalogue retrieval is user-initiated and sends no personal history.

## Phase 3: iOS

Implement UNUserNotificationCenter authorization, action routing, pending-request limits and notification timing limitations. Reconcile after lifecycle changes; do not assume Android alarms or reboot receivers exist. Evaluate AVSpeechSynthesizer installed voices and airplane-mode behaviour; AVAudioSession interruptions, route changes, AVAudioRecorder permission and file protection. Choose a documented foreground-only recording policy unless a justified audio background mode is approved. Mark data excluded from iCloud backup where supported; disclose device-transfer limitations. Use document pickers with honest provider labels and UIActivityViewController preview. Review App Store privacy labels, usage-description strings, licences and payment rules before release.

## Phase 4: desktop

Windows, macOS and Linux now have a shared desktop-core preview on the next-release branch. See [DESKTOP.md](DESKTOP.md) for implemented features, build instructions and explicit limitations. Next: native notification/tray integration, speech/recording, validated backup restore, active-use/idle/lock/suspend accounting and OS acceptance tests before a stable desktop release. Cross-device sync remains a separate opt-in project.
