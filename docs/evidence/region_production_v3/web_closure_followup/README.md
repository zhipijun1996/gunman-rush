# Finite highland runtime closure and failed woodland exclusion

Only export presets, the existing Web PCK closure checker and its tests changed. [Actual42-test log](tests.first.log) passes all35 original test functions unchanged plus7 new positive/negative tests. [Preservation](original_tests_preserved.json) and [source bindings](manifest.json) retain exact scope. No native engine, actual game export, browser or host worker was executed for this change.

All three shipping presets explicitly exclude `woodland_two_depth_ridges_v2/*`; its failed original art/source remains on disk. The existing exclusion policy now rejects its raw family files, arbitrary descendants and imported derivative if they appear inside a structurally real small PCK fixture. This is not proof a newly exported production pack already excludes them.

The actual semantic consumer calls `read_family("windmill_highland_v1")` outside static PILOT_FAMILIES. The existing finite runtime adapter now discovers such literal calls, including conditional/environment-gated consumers, rather than silently ignoring their runtime FileAccess dependencies. Actual comments and quoted explanatory strings do not fabricate consumers. Unknown dynamic family expressions require an explicit adapter update and fail closed; this is not a complete GDScript parser or arbitrary runtime dependency resolver.

The real checked-out consumer produces [8JSON/7rawPNG/12texture contracts](current_runtime_contract.json), including highland family.json/source.png, pending0. That observation reads current source/contracts and hashes only, not a production PCK or rendered scene. Highland packaging is independent of its pending visual/default admission.

New small-PCK fixture cases require highland JSON, original rawPNG bytes, actual import remap and imported target bytes. Missing/changed JSON or PNG, missing remap/target and another texture's coherent remap all reject. Existing backend-key, byte integrity, original family and chunk assertions remain. Parent must still perform the real export and existing bundle/browser checks before calling a build playable or deployed.
