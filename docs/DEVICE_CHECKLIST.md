# Real-device acceptance checklist (all pending)

Record model, Android version, vendor power settings, app commit/flavor and results. Test API 26, 33, 35 and 36, including an OEM with aggressive battery controls. A dedicated test profile is recommended for destructive restore tests.

- [ ] Airplane mode: configure 60-second work / 20-second rest, receive reminder, complete quiet break, save idea, reopen; session/history/idea persist.
- [ ] Leave app visible at work deadline: direct break transition, no duplicate notification or overlapping session.
- [ ] Notification allow/deny/revoke, disabled channel and Do Not Disturb: dashboard remains useful, no crashes or misleading delivery guarantee.
- [ ] Background, screen lock, Doze, battery saver, restricted battery, app swipe-away and force-stop: record actual delay; no false exactness claim or backlog.
- [ ] Postpone/pause notification actions: one new deadline; repeat/stale taps do not double award or overlap.
- [ ] Temporary pause expiry while backgrounded, rebooted or asleep: remaining work resumes once.
- [ ] Process kill/recreation: no duplicate session, progress, award or reminder.
- [ ] Reboot before/after deadline; forward/back clock shift; time-zone/DST shift: elapsed duration unchanged in same boot; local-time windows update.
- [ ] Twelve-hour inactivity: no stale reminder burst.
- [ ] Quiet and active hours crossing midnight; equal boundaries; suppression when visible and backgrounded.
- [ ] Offline TTS voice installed, missing, removed, wrong language, network-only voice and engine failure: never silent network fallback. Verify with airplane mode and packet observation where available.
- [ ] Narration, silence/thinking interval, optional quiz answer and deadline stop; quiet mode and muted volume.
- [ ] TalkBack enabled before and during narration: no competing speech; logical focus and useful labels.
- [ ] 200–300% text scaling, smallest phone, landscape, keyboard/Tab/Enter; reachable Cancel and Stop audio.
- [ ] Recording mic deny/deny permanently/revoke; privacy microphone toggle; very short recording; low storage; 5-minute/5-MiB limits; aggregate quota.
- [ ] Incoming call, audio focus loss, headphones removed, lock, home switch and process death during recording: no hidden capture; useful preserved note or honest failure.
- [ ] Playback/edit/rename/search/filter/delete/export; audio-only note can be renamed and supplemented with text.
- [ ] Backup with/without audio; local Documents and a cloud-backed provider; cancellation and full output storage.
- [ ] Restore preview counts/provider; replace confirmation; malformed JSON, digest mismatch, oversized data, unsupported schema, duplicate IDs, traversal names and missing audio rejected.
- [ ] Kill during staged file copy and transaction; existing data remains recoverable. Verify orphan behaviour.
- [ ] Restored achievements not multiplied; deleted history recalculates awards; gamification off leaves notes and core breaks usable.
- [ ] Share previews show exact chosen text; default share excludes audio; separate audio action includes one neutral-named recording only. Inspect container timestamps/metadata.
- [ ] Receiving app gets temporary read access only to selected cache file; unrelated files/DB inaccessible; cancel share does not claim publication.
- [ ] Delete-all removes DB personal data, recordings and share cache; old receiving-app copies are outside app control.
- [ ] Import private pack; reject invalid duration/schema/category/duplicate IDs; never execute code or allow bundled ID override.
- [ ] OS cloud-backup and device-transfer exclusion on representative vendors; document any vendor-specific exceptions.

## Version 0.2

Run the complete sequence in UPDATE-0.2.md, including popup fallback, permission revocation, active-screen accounting, offline dictation languages and persistent typed drafts. These checks have not been performed in this environment.
