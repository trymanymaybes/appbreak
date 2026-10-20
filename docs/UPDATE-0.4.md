# 0.4: cached community break catalogue

Adds `activity-catalog/` with a contribution guide, inert JSON and validation.
Existing APKs need one update to gain Internet permission and the sync mechanism.
Subsequent approved content changes do not require rebuilding the APK.

## Limits and threat assessment

- Requests use one fixed HTTPS raw.githubusercontent.com URL, default TLS validation,
  no redirects, no credentials, no user-controlled URL, no executable content or media.
- Download cap 256 KiB, max 200 activities, depth 8, bounded strings/steps/durations.
  JSON is validated before an atomic SharedPreferences body+ETag replacement.
- Initial check at idle startup; subsequent startup/resume checks weekly plus 0–24h
  jitter. Manual refresh and failures have a persisted one-day floor. No periodic
  network timer. HTTP 429/503 Retry-After delays are bounded to 1–30 days.
- At most about 1.1 MiB per installation per month for normal weekly full downloads
  at the cap; unchanged ETags avoid response bodies (not the request itself).
  Shared-IP throttling can still occur. GitHub does not guarantee unlimited raw hosting:
  https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests/
- Cached and built-in activities remain usable after errors, offline or updates disabled.
  Bundled/private IDs win collisions; active in-memory break instructions stay stable.
- GitHub receives network metadata including IP and a generic app user-agent.
  No notes, progress, recordings, identifiers, auth tokens or analytics are sent.
  INTERNET permission expands the app's network capability; the fixed URL is an
  implementation constraint, not an Android per-domain permission boundary.
- Remote text can be misleading or harmful even when structurally valid. Maintainer
  review, protected main, required checks and account security are still necessary.
  Protection settings have not been verified. No signed catalogue or rollback protection
  is claimed. Current distribution trusts GitHub TLS and repository write access.
- New step types/app capabilities still require an app update. Deleting data disables
  updates and removes the catalogue cache. Cache is not part of private backups.

## Verification

Python pack/catalogue tests and Flutter tests run locally. Android build results are
recorded in STATUS.md. Device-only tests are supplied, but are not claimed as executed.
Use DEVICE_CHECKLIST.md plus: offline cold start; first download; weekly/daily cooldown
across restarts; ETag 304; 429 Retry-After; malformed/oversize/deep payload; cache retention;
update toggle; delete data during download; notification Yes for a community activity.

## Notification tap correction

Notification content intents now carry the session ID and bring the existing app
activity forward. Native code retains `openBreak` until Flutter loads the session,
including onNewIntent warm launches. Flutter consumes it once and switches to the
break page (or pending Yes/Skip confirmation), dismissing covering dialogs.
An explicit tap can start a due break outside reminder quiet hours. Existing break
timers are preserved and stale session IDs do not start another break.

Five regression tests cover rest/pending/finished warm navigation, cold due launch
and stale IDs. Device-level PendingIntent delivery remains to be verified.

## Central permissions setup

A skippable Permission checklist opens once for new/upgrading users while idle or
working, never over an active break or notification destination. A permanent
Permissions & setup app-bar button and Settings entry reopen the same checklist.
It explains notification, optional overlay, active-screen Usage access, and optional
microphone permissions. Direct controls open the Android prompts/settings, with a
general app settings fallback after denial. Status refreshes on resume and permission
results. No blanket permission prompts are fired on launch. Microphone remains
requested on Speak/Record or explicit Allow microphone. Setup Back returns to the app.

## Dark breaks and complete manual browsing

The floating popup starts with a dark native theme and a dark Flutter theme. Normal
app break, finished, pending-confirmation and paused-break screens also use dark mode.
The activity title uses the theme's contrasting primary colour in dark mode.

Next/Previous and Choose activity now browse all installed activities except explicit
per-routine exclusions. They no longer shrink with remaining time or routine category
filters. Automatic selection still respects category, duration and exclusions. Longer
activities show a time warning; selecting one preserves the existing timer and session
identity. Quiet rest remains an explicit fallback. Tests exercise all 12 bundled choices.

## Everyday and Advanced settings; popup-first interruption

Everyday settings collect popup on/off, 15/60/120-minute popup pauses, selected
routine work interval (entered in minutes), break duration, routine preferences,
notification sound and permission setup. Advanced is one tap away and holds
language, voice tuning, schedules, catalogue controls, progress, imports and backups.
Language remains English (India) by default; existing preferences are preserved.
Setup no longer asks users to choose a language or focus mode. Subpages start at
the top, and Back returns to Everyday settings without leaving the app.

Popups are enabled by default. Setup prominently requests Android overlay access;
explicit global or per-routine opt-outs are preserved. A popup controls shortcut is
available from every screen. Without overlay permission, the UI says setup is needed.
Android can still block/delay display on locked/restricted devices.

A popup pause persists an absolute device timestamp, leaving sessions/notifications
unchanged. Native alarms include its expiry, clear the pause and can re-present a
currently due break. Pause expiry is based on device wall time, so manually changing
the clock changes the expiry. Turning popups off cancels the temporary pause; Resume
clears it immediately. Already-open breaks remain open.

New tests cover pause persistence/expiry and unchanged timers, normal/advanced
navigation, and native popup enable/pause policy. Verification for this revision is
tracked in STATUS.md; older build results do not validate these new changes.


## Unanswered breaks and the break dashboard

An expired rest/pending break is archived as missed (unconfirmed), without awarding
completion credit. Its routine starts its next interval once, and another due
routine may use the presentation slot. Unexpired and paused breaks remain protected.
The old confirmation stays usable until replacement; history retains an “I took it”
action afterwards. Confirming a historical break never changes a different current
session. Explicit skips are recorded separately from unconfirmed expiry.

Progress (Achievements) now shows completed/missed totals and dated records with
routine/activity labels. History remains available with gamification disabled.
Late confirmations keep the original recorded date and count once. Removed activity
categories stay unknown rather than earning an unrelated category badge. History is
local, included in backups, and removed by Delete session history.

New Flutter regression coverage exercises historical confirmation, duplicate credit,
current timer preservation, early exit deadlines, skipping and the dashboard. Two
native instrumentation tests cover protected unfinished breaks and once-only expiry
archiving/routine reset; these require an Android device and have not run here.


## Popup rotation and sizing

The floating break window recalculates its size on configuration changes instead
of retaining the opening orientation's pixel dimensions. Android 11+ uses current
task bounds minus system bars/cutouts; older versions use the current configuration.
Both activities explicitly support resizing. The popup has Expand/Compact controls;
resizing does not recreate the session or extend its deadline. Orientation follows
Android's rotation policy; this does not override the user's rotation lock or add
freeform drag handles on phones. Physical rotation, keyboard and split-screen
acceptance still need an Android device.


## Illustrations and pinned activity toolbar

Break activity pages and popup players now show bundled category illustrations
with optional GIF playback. Four original GIFs and matching stills cover all six
categories, including private/community activities. Illustrations are decorative;
written instructions remain authoritative. Reduced-motion mode uses stills.
No external media requests or arbitrary catalogue media paths are accepted.

Narration, stop, previous, next and choose controls are pinned in the top toolbar.
The body, including the illustration and instructions, scrolls independently in
both normal and popup views. Icons have accessible labels/tooltips and remain
compact in landscape. Activity changes continue to preserve the break deadline.
