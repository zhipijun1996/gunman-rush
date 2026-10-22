# Git checkout duplicate-blob read-only audit

Snapshot: `c305b28904214d574f6f76eb39619583e88702e3`. No source/Git modification, data deletion, archive creation or engine/test run. Sizes come from Git tree metadata; evidence bodies were not rehashed. Only111 small quality cards and bounded provenance/manifests/source references were read.

The checkout is9,104,076,797 bytes/22,891 files; docs8,585,555,469 bytes. docs/evidence is8,514,159,465 bytes/18,373 files. Exactly identical Git blobs recur across1,412 groups with3,369 extra paths, accounting for **633,618,639 duplicate checkout bytes (604.27MiB)**. This is7.44% of evidence checkout, not an explanation for all8.5GB. After retaining one occurrence per blob, evidence still contains7,880,540,826 unique-blob bytes. Git objects already deduplicate identical blobs, so worktree savings do not imply equivalent .git/clone-network savings.

| Category | Checkout bytes | Exact extra-path bytes | Extra paths |
| --- | ---: | ---: | ---: |
| JSON | 622,890,091 | 22,962,809 | 328 |
| ZIP | 1,368,116,627 | 0 | 0 |
| media | 5,220,492,198 | 508,227,234 | 730 |
| other | 1,302,660,549 | 102,428,596 | 2311 |

Arithmetic assigns one lexicographically first path per blob as a baseline only. It does not nominate that path for retention. Media includes raster/vector images and audio/video; other includes diff/log/source/compressed formats outside JSON/ZIP. ZIP0 means no byte-identical ZIP blob has multiple evidence paths; archive-internal repeated members were not inspected or ruled out.

## Largest ten exact duplicate groups

| # | Blob prefix | Bytes each | Paths | Extra bytes | Direct card paths | Manifest paths |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 0aa769af52f3 | 69,976,219 | 2 | 69,976,219 | 0 | 2 |
| 2 | ad316bff6db4 | 27,843,468 | 2 | 27,843,468 | 0 | 2 |
| 3 | 4a3e6edbe8b0 | 8,805,944 | 4 | 26,417,832 | 1 | 3 |
| 4 | f1585d3680dd | 26,007,690 | 2 | 26,007,690 | 1 | 2 |
| 5 | e27251efe247 | 9,413,401 | 3 | 18,826,802 | 0 | 3 |
| 6 | 064d0444fef8 | 2,861,736 | 6 | 14,308,680 | 0 | 3 |
| 7 | 46a603c2bdc8 | 7,085,991 | 3 | 14,171,982 | 0 | 3 |
| 8 | c334074cd39d | 9,969,230 | 2 | 9,969,230 | 0 | 2 |
| 9 | 8a940eb994ca | 7,594,192 | 2 | 7,594,192 | 0 | 1 |
| 10 | a0c4585df890 | 685,176 | 10 | 6,166,584 | 0 | 10 |

1. Examples: `docs/evidence/plains_redesign/final_current/raw/build/plains_redesign/final_regression_review/complete_committed.diff`; `docs/evidence/plains_redesign/q6_before/c2_static_review/complete_committed.diff`.

2. Examples: `docs/evidence/delivery_efficiency/actions.mp4`; `docs/evidence/plains_redesign/final_current/raw/build/verification/actions-movie/actions.mp4`.

3. Examples: `docs/evidence/p1_native/baseline_01/gameplay.mp4`; `docs/evidence/p1_native/final_a_01/gameplay.mp4`.
   Direct evidence.path: `docs/evidence/painted_terrain/media/candidate-normal.mp4` in `docs/quality/records/PAINTED-TERRAIN-01.json`.

4. Examples: `docs/evidence/plains_redesign/render_timing_diagnosis/current_content_serial_movie/gameplay.mp4`; `docs/evidence/plains_redesign/reward_entry/identity_repair/controlled_rendered/gameplay.mp4`.
   Direct evidence.path: `docs/evidence/plains_redesign/reward_entry/identity_repair/controlled_rendered/gameplay.mp4` in `docs/quality/records/PLAINS-REWARD-ENTRY-01.json`.

5. Examples: `docs/evidence/underworld_plains/delivery/browser_public_E/video/page@d3288bdeed0695340c83057cbdc2d535.webm`; `docs/evidence/underworld_plains/delivery/previous_E/browser_public_E/video/page@d3288bdeed0695340c83057cbdc2d535.webm`.

6. Examples: `docs/evidence/region_production_v3/art/boss_open_tuning_court_v1/references/1_painted_limestone_material.png`; `docs/evidence/region_production_v3/art/clock_regulator_court_v1/references/1/painted_limestone_material.png`.

7. Examples: `docs/evidence/underworld_plains/delivery/browser_local_E/video/page@3bd780d59020c6e913e101d695265710.webm`; `docs/evidence/underworld_plains/delivery/previous_E/browser_local_E/video/page@3bd780d59020c6e913e101d695265710.webm`.

8. Examples: `docs/evidence/painted_terrain/media/before-normal.mp4`; `docs/evidence/visual_language/media/candidate-normal-60fps.mp4`.

9. Examples: `docs/evidence/underworld_plains/delivery/browser_local_F/video/page@0b727693f282bdd458744098d568563d.webm`; `docs/evidence/underworld_plains/independent_review/raw_export_f/browser_local_f/video/page@0b727693f282bdd458744098d568563d.webm`.

10. Examples: `docs/evidence/underworld_plains/delivery/browser_local_E/00-ordinary-title.png`; `docs/evidence/underworld_plains/delivery/browser_local_E_hud_layout_miss/00-ordinary-title.png`.

## References are constraints, not deletion permission

At this snapshot111 quality cards (3,779,363 bytes) declare1,170 evidence.path entries/1,109 distinct paths.119 duplicate-group paths are directly named by cards, spanning99 groups. Directed manifest/index parsing finds references in1,077 duplicate groups. All top10 groups have at least one exact/relative manifest reference; two also have direct quality-card references. These include frozen inventories, archive indexes and provenance paths, whose changes would alter their hashes. Full path/card/manifests mappings are in duplicate-groups-with-references.json, direct-quality-reference-map.json and the two rg outputs.488 manifest/index candidates total17,415,052 bytes; additional bounded style/frozen and source text were scanned literally. Basename-only, dynamic joins/globs, ZIP-internal names and external consumers are not a complete static-reference closure. **No-match is not permission to delete.**

## Reversible options and compatibility risk

1. Do not delete duplicate paths as a first step. Choose one bounded group (for example the two69,976,219-byte committed.diff copies), retain its full immutable bytes once in a verified lossless archive, and create an original-path/member/size/SHA/CRC/metadata restoration map. Actually restore both paths and run exact byte/conflict/old-reference tests before considering removal of checkout duplicates. Preserve each historical source/observation context even when its bytes coincide. This is a proposal, not an executed cleanup.

2. To reduce far more than the theoretical604MiB exact-duplicate overhead, use opt-in sparse/on-demand materialization of historical evidence while preserving the original tracked paths and a complete offline byte archive. Keep runtime/tests/current authority/quality references hydrated; before a full gate, hydrate the real transitive evidence closure. Do not report a sparse subset as full-project acceptance. This preserves reversibility but needs explicit workflow/tool support and a full-coverage negative test before becoming default.

3. A future evidence object store/lossless package can store each full blob once plus all original path mappings. It must retain actual bytes and provide explicit exact-path restoration, not hash-only placeholders. Archive members/index/outer fingerprint must be bound to the original observed bytes, as in the reviewed collector. Original111 evidence.path values and historical records stay intact; changes to storage must not silently rewrite their source versions or verdicts.

Current guard compatibility: tools/quality.py requires local_file existence, hashes the exact file, validates media type and records original paths; a pointer, moved file or symlink is not a drop-in replacement. Style/frozen manifests likewise bind filenames and SHA values. Harness snapshots/source guards treat missing/restored files as source changes; hydrate before the source lease and never during native execution. Existing restore consumers need full JSON bytes, not just an index. Existing old small-artifact and77 harness tests must remain unchanged and pass. Avoid hardlinks/shared writable aliases; they can mutate historical evidence through another path. Git LFS/remote-only storage is not a complete offline solution unless real bytes and original paths are reliably hydrated. No force-push/history rewrite is proposed.

Priority: pilot reversible exact-path storage first; keep all originals and references until demonstrated. Exact-blob dedup can save at most633.6MB in this evidence subtree; most footprint is unique historical media and ZIPs and requires a separate materialization policy, not blind deletion.
