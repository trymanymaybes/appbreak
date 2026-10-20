# Version note

The following describes the original baseline. UPDATE-0.2.md supersedes its no-overlay/no-Usage-Access/no-transcription statements and documents the new permission-gated adapters.

# Architecture and behaviour

## State and clock policy

`idle → work → due → rest → finished → idle` is the normal path. `paused` retains the prior phase and remaining duration. Resume uses the retained duration; a 15-minute temporary pause automatically resumes once. Postpone starts a fresh five-minute work countdown; cancel/skip removes the active session without awarding credit. Finishing early explicitly confirms participation. A passed deadline only marks `finished`, and does not prove participation.

Every running deadline stores wall time, Android `elapsedRealtime`, and boot count. Elapsed time includes deep sleep and is authoritative during the same boot. Wall time is used after reboot. The one-second Flutter callback samples the clock; it never decrements a counter or writes once per tick. OS reboot/clock/time-zone broadcasts re-arm a single inexact alarm. A forward wall-clock change in the same boot does not change elapsed duration. After a reboot with an incorrect clock, recovery is best effort, as there is no trusted external time source.

If a running state is more than twelve hours overdue, discard it. A missed work reminder becomes one pending break, never a queue. Pause expiry resumes remaining time from observation rather than replaying a missed chain. Local-time active/quiet hours apply at delivery; reminders outside permitted hours are discarded. Manual breaks are always available. No daily auto-start schedule is implemented. End of a work session in the foreground chooses an activity immediately. In the background, Start opens the app directly using an Activity PendingIntent.

The Android receiver persists `due`/`finished` before posting a notification. Repeated broadcasts cannot post the same transition again. The same alarm PendingIntent and notification ID are replaced, not accumulated. There is at most one running session. Native SQLite uses a revision check and transaction so a stale Flutter writer cannot overwrite a receiver/recording update. A conflict surfaces an error and requires retry; the next refresh loads committed state.

## Reminder guarantees and limitations

No exact alarms, overlays, full-screen intents, foreground service, Usage Access, Accessibility Service or silent audio keepalive. AlarmManager `setAndAllowWhileIdle` is intentionally inexact. Android can defer reminders substantially; notification permission/channel settings and vendor battery policies can suppress alerts. Force-stop prevents background operation until the app is opened again. No promise of second-accurate screen-off reminders. The foreground clock is accurate to its sampled update, independently of notification delivery.

## Persistence and restore

A single SQLite row holds the versioned application document, with a revision counter. This keeps atomic snapshot restore and CAS straightforward; it is proportionate to the MVP but not ideal for very large history collections. Recordings are app-private `.m4a` files referenced by random IDs. There is no public-folder write without a picker. Notes and personal history are never pack content.

Backup v1 is UTF-8 JSON: `{format:"appbreak-backup",version:1,payload:"JSON string",sha256:"hex"}`. Payload contains `data` and a filename-to-base64 `audio` map. The SHA-256 covers the exact UTF-8 payload string. This detects accidental corruption; it is NOT authenticity, encryption or protection against an attacker who recomputes the digest.

Limits: 24 MiB total input, 10,000 ideas/history records each, 100,000 characters per note, 200 title characters, 5 MiB per recording, 16 MiB decoded audio aggregate. No ZIP extraction is used. Recording keys must match UUID-shaped safe basenames and MPEG-4 `ftyp` signatures; no supplied directory path is accepted. Unsupported schema versions, duplicate IDs, malformed fields and missing referenced audio are rejected. Activity packs are capped at 1 MiB/200 activities.

Restore validates before confirmation; creates new audio files under fresh IDs; fsyncs those files; then swaps the SQLite snapshot in one transaction. Invalid/failed pre-commit restores leave the old database and old referenced files intact. A crash during staging can leave unreferenced files, but cannot overwrite the old ones. Cleanup after commit removes old recordings. Running sessions are not restored. Restore REPLACES rather than merges, so duplicate IDs in the imported snapshot are rejected. Achievements are recalculated using rule version 1 and unique session IDs, preserving the history's participation dates; content edits do not retroactively change stored session categories.

Do not assume SAF destinations are local. The picker can represent remote providers; returned provider authority is displayed after export and before restore. Encryption/passwords and merge restore are deferred.

## Audio and accessibility

Text is always available. Quiet mode is default. Narration starts only from a user button; only installed, non-network-required voices matching the activity language are accepted. A missing voice produces an actionable error and an optional system voice installer. An external TTS engine declares whether its voice needs network; it is a separate app and must be tested in airplane mode. The companion itself has no network permission. No cloud recognition/transcription.

TalkBack touch exploration disables app narration; use TalkBack reading. Stop-all-audio is always reachable. Start/end haptic and tone cues are optional; progress is visible without them. All break controls are text-labelled, keyboard-focusable Flutter controls with system text scaling. Timer text is excluded from per-tick semantics; a dedicated button announces remaining time. There are no custom motion effects or animated rewards.

Narration supports stop and replay. Session pause/resume preserves the countdown, but narration replay starts instructions again; sample-accurate audio pause/resume is not implemented. Structured silence/thinking is queued; completion is tied to the actual session deadline rather than finishing the speech queue. Long spoken instructions are stopped at the break deadline, never extend the break. Activity estimates should leave adequate speech time.

Recording is only user-initiated. Permission is requested when Record is tapped. The user taps again after permission grant. Narration stops before microphone use. Recording has a five-minute/5-MiB limit and a 100-MiB aggregate quota. It stops/saves on background or screen lock, audio-focus loss, or a native limit callback. Too-short/failed recordings are deleted and a failure event is emitted. Incoming-call and microphone-privacy-toggle behaviours vary by device and remain mandatory hardware checks. Storage and recording errors never award progress. Foreground recording is intentionally not extended using a service.

## Sharing

Only explicit Ideas/Achievements UI actions invoke the share adapter. Text payloads are constructed from the selected text or single milestone, never full state. Editable preview precedes the OS share sheet. Audio is a separate explicit action, with a listen-before-share control and neutral attachment filename; no audio is attached to text sharing. Temporary read-only content-URI grants expose only a prepared cache copy. Shared copies expire from app cache on later sharing after 24 hours and are removed by delete-all; copies already received by other apps cannot be recalled. Audio container metadata needs release privacy inspection before declaring metadata scrubbing complete.

## Extension boundaries

The Android `Device` implementation is replaceable without changing pure Dart rules. Future platform adapters implement clock, persistence, scheduling, TTS, recording, user-selected files and sharing. Split the method surface into narrower interfaces once a second platform is built. There are no speculative empty billing or transcription classes. Future store dependencies belong to `playImplementation` and `src/play`, not runtime flags.

Debug-only Android manifest permits the Flutter VM debugging connection. Statements about no app INTERNET permission refer to the release manifests, not the development build.
