# Community break activities

Contribute through a pull request editing `catalog.json`. No APK rebuild is needed
for content using the existing schema and step kinds. README is for people; the
app fetches JSON from the fixed HTTPS URL on main.

Use a stable unique `community.` ID, CC-BY-4.0 licensed original content, author and
attribution, a supported category, 20–300 second duration, and accessible alternatives.
Only plain text instructions, narration, thinking, silence and completion are allowed.
No scripts, HTML execution, external media, links that the app opens, or remote commands.
Do not add medical claims, strenuous/unsafe movements, personal data or advertising.
A maintainer must review safety, accessibility, originality and attribution before merge.

Run `python3 tools/validate_catalog.py` and `python3 -m unittest discover -s tools`.
Limits: 256 KiB total UTF-8; 200 activities; 30 steps/activity; 2,000 characters per
text field; 20 accessible alternatives; maximum JSON nesting 8. Unknown keys are
rejected. Keep IDs stable; do not reuse an ID for a different activity.

The app checks on startup/resume while idle, weekly plus up to 24 hours of jitter.
Failures retry no earlier than a day later; manual refresh has the same daily floor.
HTTP 429/503 Retry-After is respected up to 30 days. ETags avoid unchanged downloads.
No background polling, accounts or API tokens. Turning updates off keeps cached content.
Delete all local data also clears this cache and disables network updates.

Maintainers: protect main with required review and required validation checks, use 2FA,
and restrict write access. These repository settings must be verified separately;
this file does not enforce them. A compromised maintainer could publish harmful text
within the schema: validation is not editorial safety review or cryptographic signing.
