# 0.4 Web dependencies and selection recipes — independent static review

**Accept the limited static Web-dependency and selection-recipe scope. No blocker found.** I reviewed sources, ASTs, SHA receipts and the author's pure-test logs without running Godot/browser/export or the pure suite. I did not modify reviewed files; only this report and JSON were written. Host/job scheduling remains WIP and is not signed.

The three frozen files still match the author's receipt:

| File | SHA256 |
|---|---|
| export_presets.cfg |58082d5f88815222eeb41576afc4ce7adfce7e486dee815d520d917ff0a3758f|
| tools/check_web_bundle.py |23ee80d352cdda99780d4c80ab4a9698291b5de77ea114f3caa7268d7567ee33|
| tests/test_web_bundle.py |c89ceaff6412b42d2e65d31ba5e6b439b2debb0c80c91fde5fd9da334fc0959a|

## Finite dependency migration

Checker172-180 obtains the18 original SDK script revisions and23 installed pins from the existing installer/preflight, then actual config conformance/gears_conformance fields. There is no second SDK hash registry. The shared generator config deduplicates naturally; the original gears930007 request is additionally required. Config lock remains09c2…. ZIP/dev exclusions in check_mapgen_payload are **byte-exact to the prior source**: no Python/pyc/pyo,docs/tests/tools/evidence payload, or additional ZIP is admitted. The sole allowed ZIP remains exact module-pack1.1.0/SHA5ad5…. Raw hashes and unique normal remap/nonempty targets remain enforced; raw JSON/data presence is still required.

Two binding SHAs come from actual consumer constants, not a copied registry. Default GeneratedSlice.DEFAULT_BINDINGS_PATH/SHA256 resolves resources/levels/mapgen_host_v4/bindings.json, SHA `182b4b50da807ace3b38b327645d156f02f73286d976b4de6dbace4590bc2809`; M35Slice.BINDINGS_PATH/SHA256 resolves resources/levels/mapgen_host_v4_gears/bindings.json, SHA `ef7fab5184d503c11d3ce0990f802acc620ec68ff070dacdbc242adec474ca4c`. I independently read the current declarations and hashed actual files. Checker275-294 requires one finite declaration of each expected constant, exact permitted path and valid64hex matching local bytes. Missing/duplicate/different paths and wrong SHAs fail. Actual PCK closure later requires exact local JSON bytes as before.

Only Web Playtest's include filter changed: remove old03M35 binding include, add exact gears request and two04 binding paths. No resource wildcard was introduced. All other include members, all three presets' exclude filters and the original seven frozen02 JSON are unchanged. The old03 binding source itself is not deleted. Frozen consumer/input-lock/raw-byte validation remains intact.

## Old tests and meaningful new failures

I independently proved all71 old test methods remain and every original assertion remains after the finite15→18 SDK count and added required-gears set updates. Four new methods yield75. Harness web-resource-contract-tests definition, including timeout60 and original success marker, is unchanged. New tests exercise missing/altered binding PCK bytes, changed local binding despite consumer SHA, different/missing/duplicate consumer constants, coexistence of both04 consumers with original frozen7, additional ZIP refusal, and missing/relabeled/wrong-byte gears request. Earlier tampered-MD5-resigned bytes, addon/remap/development payload and frozen-contract negatives remain.

Author logs actually report75 tests/OK/exit0 in1.6184 seconds under the60-second budget; the dependency vector stayed stable, and every recorded input leaf still matches at this review. The earlier7-test SDK-only subset is explicitly separate. These are meaningful small format4 byte fixtures written by an independent fixture writer, **not the exported game's actual PCK** or a Godot/rendering run. GDC fixtures explicitly establish structural presence, not executable semantics. No new full pack/export/readback/browser claim follows from75 pure tests.

## Selection helper at reviewed SHA

Reviewed helper SHA is `d9f38198054b1e951bfc04765524d06a90d7f87e8fa48dec1b26717444bc4da1`. It is a pure result/recipe/body→resolution function; it creates no nodes, calls no solver, changes no content and grants no services/session authority. The two pinned recipes contain empty selected_instances/spawns and explicit physics-required scope, not old M IDs or coordinates.

Helper6-29 requires a completed map/store and finite positive actual body half-extents, unique nonempty IDs, and exactly one root matching module_id/content_version/role. Default32-45 follows root R→first junction entry_left, first entry_right→second entry_left, and first exit_upper_right→that same second exit_upper_left, all ROCK; repeated instances or ambiguous neighbors reject. The full selected internal edge set must be exactly the three resolved edges (66-74), so extra/omitted internal topology does not silently pass. Gears46-51 uniquely selects its exact template/version/traversal with unmirrored materialized output and no seals; expected internal edges is0. It does not select the old930001 M35 by label.

Each selected content_ref must resolve to actual store data with matching stable_id, materialized transform and finite actual origin. Spawn75-91 uses the actual selected root's original platform0 top-center, subtracts actual body_half.y, then adds actual origin_blocks×128. It does not mirror or apply source_affine again. The128-pixel contract is explicitly enforced by downstream Provider coordinates gate; this helper is not a standalone map-schema validator. Width/ceiling/full support and standability remain the existing physics admission's job. The resolution records current fingerprint, actual identities/origins/transforms/connections and actual body/local/world spawn, with derived IDs/spawn replacing recipe placeholders. No old spawn or restore identity is reused.

I read the call boundary only: job validates the original Protocol fingerprint and gets collision_half_extents from the actual request capability snapshot before selection, then passes the resolved IDs/spawn/bindings to the shared Provider. This does not sign its still-changing scheduler, actual capture timing, assembly, cancellation or commit behavior. A real native run must establish the final body/selection/spawn and physics barrier; actual export/PCK and Web evidence must bind that final source separately. Whole-map, route, phone and performance acceptance remain outside scope.
