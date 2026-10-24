# Contributions and private activity packs

Original application code is Apache-2.0 and original activity content is CC-BY-4.0, approved by the owner on 2026-10-18. Contributors must have the rights to submit their work under the applicable licence.

An activity pack is UTF-8 JSON, schema version 1, containing `schemaVersion` and `activities`. Use `schemas/activity-pack.schema.json` and `assets/activities.json` as examples. Packs are data only: no scripts, plugins, HTML execution or downloaded executable code. Private packs import through Settings and remain on the device. Personal notes are never automatically offered for contribution.

```bash
python3 tools/validate_packs.py path/to/pack.json
flutter test
```

Use a stable namespaced ID (`yourname.activity-name`). Translations retain semantic identity through a stable base convention such as `yourname.activity-name.hi`; language is a BCP-47 tag. Preserve IDs across wording corrections; create a new ID when meaning/category changes. Existing history preserves the original recorded category. Add a documented migration for breaking schemas; unknown versions must fail safely.

Every activity needs title, category, language, estimate, description, structured instruction/narration/thinking-or-silence/completion steps, visual/input flags, accessible alternatives, author, attribution and content licence. Supply explicit source attribution and a compatible permission/licence for contributed work; no copied copyrighted riddles or unattributed translations. Original bundled content is CC-BY-4.0. Any future pending or unknown licence identifier must be resolved before public distribution.

Review before community publication:

- Clear, short instructions; comfortable participation in 20–300 seconds, including narration time.
- Quiet rest and a seated/non-movement option; no punishment for replacement or skipping.
- No strenuous exertion, forced breath-holding, diagnostic advice or eye-rest/health guarantees.
- Audio-only pathway, complete text equivalents, honest visual/input flags.
- Quiz question first, sufficient thinking time, optional answer reveal without answer buttons.
- Respect language, reading level, culture and translation quality; do not change IDs accidentally.
- Review with a screen reader and installed offline voice; test actual spoken duration.
- No requests for sensitive disclosures; recording/sharing never earns rewards.
- Run validator, inspect attribution/licence, and obtain human content review.

Community code changes require review, tests and an application release. Content packs never execute code. Public catalogue updates use the reviewed content process below.

## Public activities and optional routine bundles

Propose content through a PR; only maintainers publish by reviewing and merging to main. Read [the protocol and lifecycle](docs/CONTENT-PROTOCOL.md) first, including the branch-protection limitation.

Copy `activity-catalog/activity.template.json` or `routine-bundles/bundle.template.json`, change stable IDs and author/source/licence, then add entries to the corresponding **v1** catalogue. Do not change the legacy activity endpoint's field set. New published activities require positive contentVersion and source. Increment contentVersion/version for revisions and preserve identity. Informative media needs accurate alt and actionable fallbackText; nonvisual activities do not need invented visual alt text. Templates are examples, not placeholders suitable for publication unchanged.

```sh
python3 -m pip install jsonschema==4.23.0
python3 tools/validate_content.py
python3 -m unittest discover -s tools
```

The PR checklist, schemas and validators catch structural mistakes; maintainers review content quality, safety, timing, accessibility, source rights and licences. CODEOWNERS alone does not prevent unreviewed merges. App/protocol/renderer changes also require Flutter analysis/tests, Android build/native checks and appropriate device acceptance. Content-only PRs do not build APKs.
