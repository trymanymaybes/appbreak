# Excluded apps

Settings → Break popups → Excluded apps provides a searchable list of installed launcher apps. Check to exclude; uncheck to remove. Selection saves immediately and applies to every routine and retry. Grant Android Usage Access using Allow on that page.

Automatic popups are suppressed while the last foreground app is excluded. Existing notification preferences, timers and explicit notification taps are unchanged. With exclusions configured, missing permission, query errors or unknown foreground state suppress automatic popups conservatively. With no exclusions the original behavior is preserved. Detection uses up to 24 hours of usage events without storing observed packages or usage history. Selected package IDs are stored locally and included in explicit backups. This supersedes older release notes saying no package names are retained.

Only foreground use is covered, not background navigation services, picture-in-picture or split-screen guarantees. An already-open popup is not dismissed by this change.

Device verification: select a navigation app, grant Usage Access, trigger a break while it is foreground and verify notification without popup; retry a reminder and repeat for a scheduled routine. Switch to a non-excluded app and verify normal popup behavior. Revoke Usage Access and verify notification-only behavior. Uncheck all apps and verify original behavior. Restart and export/restore to verify selection persistence. Test notification taps, search, removal of uninstalled selections and denied notification permission.

Validation (2026-11-08): Flutter 3.35.7 analysis passed with no issues; all 129 Flutter tests passed, including app search, selection persistence, removal and failed-save rollback. All 19 Python tests and the content/pack/catalog validators passed. Native Android tests, APK build and physical-device verification have not been run for this change.
