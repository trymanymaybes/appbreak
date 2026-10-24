# Many Maybes challenge browser

The active Many Maybes activity discovers challenge links from https://trymanymaybes.github.io/challenges.html. It loads the selected challenge page on demand, reads its description and starter alt text, and displays the site's starter image directly over HTTPS. PNG links are read from the page; SVG-only starters also work. No challenge images are bundled with the app. New numbered challenge pages linked from the catalogue do not require a new app release.

Previous/Next wrap through the available challenges; Jump to challenge supports direct selection. Refresh challenges rechecks the site. Disabled activities stay excluded. Navigation keeps the break deadline, gives no completion/skip credit, and finalizes active recording/dictation before changing the associated challenge. Completion, history, idea review and idea-card export support new challenge numbers.

Play/replay reads the site's description and alt text, then asks the participant to imagine a possibility. If the description is absent, narration uses the alt text. Quiet mode and the existing TalkBack/narration safeguards still apply. Site content is parsed as data; HTML scripts are not executed.

Up to 200 recently opened challenge descriptions are retained locally and included in backups. Images are requested from the site, with alt-text fallback if unavailable; there is no offline image guarantee. A failed page request preserves the current challenge, or uses its previously loaded text. Bundled imagination text remains the first-run offline fallback. Network requests have time and size limits. If the site's catalogue/page structure changes, failure is shown with Retry and an external challenge link rather than silently displaying a different challenge.

Validation: clean Flutter analysis; 79 Flutter tests, 14 Python tests, bundled-pack and catalogue validation passed. Tests cover discovery beyond 100 challenges, actual image links, SVG and alt-only narration, stale loads, timer/recording/history association, navigation and network failure. The six live site pages were checked with the same parser. Android CI builds and native tests are tracked on PR #3. Device-level image loading, voice playback and instrumentation execution still require Android acceptance testing.

This is a source change after the published 0.5.0 release.
