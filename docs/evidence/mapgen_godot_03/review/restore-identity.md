# MAPGEN-GODOT-03 generated restore identity /2 supplement

**ACCEPT for the single identity literal, four new regression assertions and narrow static delta below.** Non-author read-only source/original-log review; no Godot/browser/Harness execution or production edits by this reviewer. Prior reports, failed runs and old Web spawning limitation remain unchanged.

Reviewed commit8033aa15e65028945a380969d789235739835ddd and current M35-combined Provider SHA256 `91e63534c4ec8dbe417985bc30fc367b4891ac36f31e7ac76200589fefd7f776`. Identity runner SHA `f0bda53931b23318dd734aa7ee99d1684163feb04b1b2b0aca3b8148553a2aae`.

## Exact source change and identity separation

The commit changes only the generated host_load.adapter_version literal from runtime-map-generated/1 to /2 and adds13 runner lines/four checks. Independently reverse-replaced that single literal in the current Provider: the entire source becomes byte-exact to the already reviewed M35 Providerf4ab815ec0e5a178dbdb6c645c6e6d22c1324a22ae378b80643c1d7347345450. No other Provider mapping, validation or behavior delta is hidden in this supplement.

Independent function comparison confirms frozen `_load_identity` and `_digest` are byte-exact. The complete generated map-content construction/digest before host_load is also byte-exact: same original actual map/content_store, package/module/input digests, upstream generation fingerprint and MapContentIdentity. Only memory **host-load** identity changes. Frozen adapter/version, original state/permanent-save schema and algorithm request_fingerprint/map_id are not rewritten. This appropriately distinguishes the corrected host spawning/load contract from unchanged algorithm output and from frozen-source saves.

## Four real restore checks

Runner lines102–113 rebuild the old host Dictionary using the exact old schema/source-kind/adapter version and original selected IDs sorted independently, binding schema/version/data digest, active binding, spawn, region/index and captured capabilities. It computes old_host_hash with original Godot sorted-key/full-precision JSON, rather than using the current host hash and calling it old.

The reused MapContentIdentity is intentional because the same payload and that identity construction are byte-exact, as separately checked above. It is not the changed current host-load identity. The four checks require current /2 plus a different old hash; bind an actual PlainsRegionState to the reconstructed /1 hash; successfully restore its snapshot under that original hash; and refuse that valid old snapshot under the corrected current hash. Reverting the host literal would fail the new-version/hash-difference and old-record-refusal assertions. Existing24 complete assertion-line occurrences are retained, with exactly four new ones added; total executed checks48 includes their existing parameterized cases.

The change deliberately rejects old **generated-memory** run-local records even for the same map/bindings. It does not invent a migration or rename the upstream generation fingerprint.

## Original runtime evidence inspected

Read `/tmp/mapgen-v3-audit/generated-identity-v2-01.log`: marker RUNTIME_MAP_GENERATED_IDENTITY checks=48 failures=0, SHA256a1038c55f06e9b88a40c2f4288f73d60c9931adbab17c3d0b7c5369d1eae87a9. No ERROR/script/parse/shader/leak/resources-in-use lines found.

Also read corrected-default `/tmp/mapgen-v3-audit/spawn-fixed-generated-slice-01.log`: marker RUNTIME_MAP_GENERATED_SLICE checks=56 failures=0, SHA256f37969034a2d80300b4bc9f7df2dab269cd1a294dfcd132a6f4cd2e0ce952c84. No strict diagnostic lines found. Its source test includes the real segment_returned event/body-position regression introduced by231049be; this is not merely matching a requested spawn field. These are root-executed original logs, not independent runs by this reviewer or a substitute for final same-commit combined Harness evidence.

## Ancillary static guard/diagnostic scope

Read M35 source SHA62883709d43a209daf7d430009157269bc1bf20b360513c8a29ac1b77c4018fb: physics admission now additionally requires template_id game-plains-ferry-gears for the single instance M35. It narrows the explicitly controlled scenario if a later layout reuses that instance ID for another template; it does not grant abilities, move actors, edit geometry or change the original motion/damage functions.

Common slice SHA5838b45343a7f81e1ebe899a2ea921cdfbba3ddda2be0b6c83413824d61c1c4b remains the reviewed read-only mechanism/static_contacts snapshot: it reads existing values and writes only diagnostic dictionaries/console output. No physics or settlement mutation was added. No additional acceptance is inferred from this diagnostic.

No confirmed blocker in this narrow delta. Final same-commit Harness/frozen-target regression and any new M35 Web/ride/pause/reload/device/full-map claims require their own evidence. The5b0 raw player[0,0] remains an original failure of correct spawning; later identity versioning/native success does not retroactively correct it.
