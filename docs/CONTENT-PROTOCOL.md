# Downloadable content and routine bundles

Content stays in this repository and contains data, never executable plugins, scripts or HTML. Compatible additions require a reviewed content PR, not an APK rebuild. A new renderer, trigger, step kind or capability requires application work and an app release.

## Endpoints and release boundaries

- Existing released apps retain `https://raw.githubusercontent.com/trymanymaybes/appbreak/main/activity-catalog/catalog.json`. Keep this endpoint on the original v1 subset, including its strict field allowlist. Do not add extended fields there.
- Updated apps use `https://raw.githubusercontent.com/trymanymaybes/appbreak/main/activity-catalog/v1/catalog.json`.
- Optional bundles use `https://raw.githubusercontent.com/trymanymaybes/appbreak/main/routine-bundles/v1/catalog.json`.
- Many Maybes continues discovering challenge links from `https://trymanymaybes.github.io/challenges.html`, loading selected pages and their images on demand. It is independently maintained website content, not governed by this repository's approvals.

Raw main is the publication channel: merging into main makes content available. No PR branch is a production source and no workflow publishes an APK. Maintainers must review content before merging. CODEOWNERS requests review; it does **not** enforce approval. On 2026-10-24, repository rulesets returned an empty list; the main branch-protection API returned 403 (integration lacks access). Approval enforcement cannot be verified or configured with the available access. An administrator must require PR review (including code owners), dismiss stale approvals, restrict bypass/direct pushes and require Content validation before treating publication as technically approval-enforced.

Activity refresh retains bounded JSON, HTTPS/no redirects, ETag revalidation, last-good cache, a one-day background attempt floor, one-minute manual refresh floor, server cooldowns and weekly automatic refresh. Invalid/unsupported responses never replace cache; active breaks retain their selected instructions. Bundle refresh is explicitly requested from its browse page, bounded to 256 KiB, 100 bundles, nesting depth 8 and 20 seconds. It validates the entire response before saving the last-good catalogue locally; failures retain the previous cache. No polling or automatic bundle installation occurs.

## Activity v1 and additive content metadata

`schemas/activity-pack.schema.json` is the common pack format for bundled, community and private import content. Each activity has a stable namespaced `id`, integer `schemaVersion: 1`, positive integer `contentVersion`, title, description, category, language, estimatedSeconds, steps, visual/input requirements, accessibleAlternatives, author, attribution, source and contentLicense. New published content requires contentVersion and source. Older v1 imports may omit them; their effective content version is 1. The schema keeps those fields optional for backward compatibility. The published-profile validator enforces the stronger requirements.

Supported categories are quiet, movement, breathing, hydration, quiz and imagination. Estimates are 20–300 seconds and include time for narration. Steps are ordered: instruction/narration/completion have text; thinking/silence have explicit integer seconds. Total explicit silence cannot exceed the estimate. Speech runs at the user's voice rate; silent timing is fixed. No content may introduce new step kinds.

Optional `media` is an array of up to four objects with `url` (HTTPS), `alt` (meaningful visual description) and `fallbackText` (usable participation instructions without the visual). The renderer handles raster images; unsupported formats or failures show text. The app displays alternatives and includes them in narration. Raster images use a bounded private cache (4 MiB/image, 20 MiB total, at most 4096 pixels per dimension and 8 megapixels). Previously viewed valid images survive app restarts while Android retains the cache. HTTPS redirects, invalid image bytes and oversized media are rejected. SVGs in the Many Maybes adapter still use its existing online renderer. Cache is not included in backups; text alternatives remain available. Do not create alt text for an activity with no informative visual. Existing decorative bundled animations remain excluded from semantics. Schema validation checks presence/nonblank text; human review is required for accuracy and usefulness.

`reflectionQuestion` is optional. `answer` is optional and revealed only by the existing user-operated reveal control. `reveal: "manual"` documents this supported behaviour; absence has the same legacy meaning. No automatic scoring, scripts or downloaded answer logic.

### Many Maybes adapter

`ManyMaybesSite` parses the live website as data, without executing it. `ManyMaybesChallenge.toActivity` supplies the shared instruction/thinking/narration/completion representation, source URL, attribution and stable `manymaybes.challenge-NN` identity. The `manyMaybes` adapter metadata retains the page description, actual image link and website-provided alt text for the specialised browser. It is not accepted in public community catalogue entries. Remote descriptions/alt text feed narration; missing media leaves description-based imagination available. No invented visual description is generated. The current app's existing 18 offline activities (including six legacy challenge starters) are retained to avoid removing offline functionality or changing historical IDs; newly discovered challenges are not bundled.

### Migration and identity

No destructive storage migration or ID renaming occurs. Legacy v1 imports/backups remain accepted. Historical entries, notes, recordings and completion credit continue using stable activity IDs, not catalogue positions, titles or content versions. Wording corrections increment contentVersion without changing ID; fundamentally different activities need new IDs. Private imports take precedence over catalogue entries of the same ID; bundled IDs cannot be replaced by import. Unsupported schema versions, unknown catalogue fields, step kinds and reveal modes are rejected, preserving last-good data. Older applications continue using their unchanged legacy endpoint; extended catalogues must never be placed at that URL.

## Bundle v1

`schemas/routine-bundle.schema.json` validates one bundle; `routine-bundles/v1/catalog.json` wraps a `schemaVersion: 1` and `bundles` array. Use `routine-bundles/bundle.template.json`. Required fields: stable id, integer version, title, description, author, license, workActivity, minimumProtocol, dependencies, defaults and customisable.

`minimumProtocol` must be 1. Dependencies are stable activity IDs with minimumVersion. Supported defaults: workSeconds (60–14400), breakSeconds (20–300), trigger (manual/interval/screen), selection (rotation/fixed/choose), quiet and repeat. `customisable` explicitly lists which of those settings may be changed before installation. Fixed selection uses the first dependency; rotation cycles only the referenced activities; choose starts with quiet rest and permits user choice. Work activities are descriptive labels, never executable tracking logic. Screen trigger uses existing Android usage access; manual reading/studying does not infer whether someone is reading.

### User flow and lifecycle

Routines → Browse optional bundles → Download / refresh catalogue → choose a bundle → preview/customise → Add disabled routine. Preview shows dependencies, version/author/licence, work activity and settings. Installation revalidates the bundle and all dependencies against current local/bundled/catalogue content, including minimum versions and duration fit, before one revision-checked save. The preview provides Download required activities: an explicit one-time download that does not enable automatic updates. Missing activities or unmet minimum versions still block installation with a clear error. There is no partial install. Nonbundled dependencies are retained in private local activity storage for offline use.

Installation creates one uniquely identified local routine, with enabled/popup/notifications false; no global setting or Android permission is changed. Duplicate installs are rejected. Downloading a newer catalogue never changes installed routines. When a newer version is selected, the preview offers Update existing routine; it revalidates dependencies, keeps the same routine ID/name and current local settings/reminder state, and rejects updates during that routine’s active session. Untouched bundle activity selections follow the new dependency list; explicitly edited selections and older installs without selection provenance remain unchanged. Edit the routine normally; use "Use all activities in selected categories" to remove its bundle activity restriction. Updates are explicit and atomic. Existing pinned/imported activity data is not silently replaced by newer remote content; if its version is too old, dependency validation blocks the update rather than overwriting personal content.

Delete in Routines removes the local routine without deleting history, notes or dependency content, which may be shared or referenced by previous records. A current break must be finished or skipped first. Dependency data follows existing backup/private-pack semantics. Cached catalogue JSON is revalidated before use. Imported extended activity metadata and local bundle provenance survive backup; old backups with none of those fields remain valid.

## Checks and limitations

Content validation runs independently on all pushes/PRs. Source checks skip changes confined to activity-catalog/, routine-bundles/ and Markdown. Changes to app code, loaders, renderers, schemas, validation tools or workflow files still run full Flutter/native/build checks. Bundled defaults in assets/ are application changes. Example templates are validated too. No external media availability check is required to merge: offline alternatives must work, and maintainers must inspect media and licence claims.

Physical-device checks remain essential for TalkBack, narration pacing, media failures, background reminders, permission behaviour and restore. Compiling an instrumentation APK is not executing those tests on a device.
