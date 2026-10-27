# Dependency and asset audit (partial)

No third-party Flutter plugin is used. Direct runtime dependency is Flutter SDK only; dev dependency is flutter_test. Platform functionality uses Android APIs. `pubspec.lock` records exact resolved packages and hosted checksums. This inventory includes test-only transitive dependencies as well as runtime dependencies; do not treat every entry as APK contents.

Flutter 3.35.7/Dart 3.9.2 was fetched from the official source and successfully used for analysis/tests. Flutter is actively maintained but this pinned baseline is older; current-stable upgrade and native toolchain maintenance review remain release gates. All listed package licence files were read locally and retained verbatim. Android SQLite/TTS/media are OS APIs. A device-installed speech engine is external, not bundled, and must be offline-verified.

| Package | Resolved version | Licence inspection |
| --- | --- | --- |
| async | 2.13.1 | BSD-style (see retained text) |
| boolean_selector | 2.1.2 | BSD-style (see retained text) |
| characters | 1.4.0 | BSD-style (see retained text) |
| clock | 1.1.2 | Apache-2.0 |
| collection | 1.19.1 | BSD-style (see retained text) |
| fake_async | 1.3.3 | Apache-2.0 |
| leak_tracker | 11.0.2 | BSD-style (see retained text) |
| leak_tracker_flutter_testing | 3.0.10 | BSD-style (see retained text) |
| leak_tracker_testing | 3.0.2 | BSD-style (see retained text) |
| matcher | 0.12.17 | BSD-style (see retained text) |
| material_color_utilities | 0.11.1 | Apache-2.0 |
| meta | 1.16.0 | BSD-style (see retained text) |
| path | 1.9.1 | BSD-style (see retained text) |
| source_span | 1.10.2 | BSD-style (see retained text) |
| stack_trace | 1.12.1 | BSD-style (see retained text) |
| stream_channel | 2.1.4 | BSD-style (see retained text) |
| string_scanner | 1.4.1 | BSD-style (see retained text) |
| term_glyph | 1.2.2 | BSD-style (see retained text) |
| test_api | 0.7.6 | BSD-style (see retained text) |
| vector_math | 2.2.0 | BSD-style (see retained text) |
| vm_service | 15.4.0 | BSD-style (see retained text) |

Build tooling: AGP 8.11.1, Gradle 8.13, Kotlin 2.1.0. Native dependency resolution and FOSS release compilation succeeded. The actual graph is retained in foss-runtime-dependencies.txt and cached POM licence declarations in native-pom-licenses.txt (including resolved candidates, not all necessarily packaged). A coordinate scan found no Play Services, Firebase, billing or Facebook SDK. The ARM64 artifact contains libapp.so and libflutter.so; Flutter NOTICES.Z is retained. Complete upstream licence-text/engine-source review and F-Droid scanning remain release gates.

Assets: original activities are licensed CC-BY-4.0. Default Android launcher/template resources originate from Flutter SDK templates (BSD licence retained). Material Icons and engine/font notices must be retained and checked in the compiled release. No photos, network content, proprietary voice assets, billing, ads or analytics SDKs are bundled by app source.

FOSS/Play separation is structural via Gradle product flavors. Both currently share the same free local implementation; future proprietary distribution integrations must live exclusively in Play source/dependency sets. No runtime payment switch is used. Initial FOSS artifact and runtime classpath checks are recorded in apk-audit.txt; future dependency changes require repeating them.

See RELEASE.md for exact audit commands, and OFFICIAL_SOURCES.md for official policy references. Not F-Droid approved; original code is Apache-2.0 and activity content is CC-BY-4.0 (owner-approved).

Debug builds declare INTERNET solely for Flutter VM-service debugging, as in the standard Flutter Android template. Release builds do not merge src/debug; inspect the actual release manifest to verify this. Offline acceptance must use a release build as well as a debug build in airplane mode.

Version 0.2 adds test-only JUnit 4.13.2 (EPL-1.0) for pure native accounting tests. It is scoped to testImplementation, not either APK runtime graph. Android on-device SpeechRecognizer, UsageStatsManager and popup launch use platform APIs; no runtime plugin or speech model dependency was added. JUnit is a legacy test-only baseline; no new runtime dependency maintenance claim is made.

JUnit brings test-only Hamcrest Core 1.3 (BSD). The JUnit and Hamcrest licence texts were inspected from the resolved JARs and retained under third_party/licenses; neither is bundled into the app runtime.

Desktop preview adds Flutter-published path_provider, file_selector and url_launcher plugins, plus Dart crypto. Exact direct and transitive versions are pinned in pubspec.lock; Flutter collects their licence notices. They provide application-support paths, user-chosen file dialogs, HTTPS link launching and backup/cache hashes. Android platform operations continue using the existing native adapter. Desktop native release and licence audits remain release gates.
