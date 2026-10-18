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
