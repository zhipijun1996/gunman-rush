# Root-bell coin guard: final bounded review

**ACCEPT**, limited to guard source and matching development records at `2c32948271b2f002f76aea846a83aa1cba4f0a13`, compared with `a5ff2ccb9bd59efc79eb5fb1bc2b6e59de0f4249`. Reviewer `/root/guard_review_recovery` did not author production or either changed guard file, did not run Godot, and made no repository edits. Root authored the implementation and fixes after reviewer reported concrete counterexamples.

The development03 run is a precommit execution with a5ff plus two dirty guard files. It is **not a Git-clean execution**. Its `source_before == source_after` inventory has **2969 items**, all independently matched by SHA256 to local bytes and by Git blob hash to frozen 2c329. Exactly the two guard inputs differ from a5ff; the other2967 captured inputs and all production bytes are unchanged. Original report/audit/runtime archives are byte-identical to development originals.

The narrow permission is sound: only the real admitted same-ID charger→root_bell replacement can change drop economics. The old/new totals come from the unchanged config (2→7). A deep copy of the old row changes only behavior, three amount totals, and the unique coin reward amount; the complete expected dictionary must equal the new row. Other rows remain fully equal. This preserves RNG, stream position, bonuses, keysets and reward order. Both budgets must be integers with precisely that configured delta. Actual species are checked before the equality branch, closing the old-drop plus old-budget rollback.

Root's observed native03 record shows exit0 and clean runtime, **40 maps / 10 physical refusals / 12 species refusals / 2 historical save versions / 3 replay versions**, fixed60Hz, native51.636seconds under unchanged240 budget. All original non-run GDScript functions and wrapper main remain identical; Harness profile bytes,360 budget and original six Python mutations remain unchanged. Reviewer independently reran pure receipt validation and all eight Python refusal mutations. The full source/record proof contains **3021 checks,0 failures**, including2969 per-input comparisons; this count is not engine test cases.

Previously found defects are addressed and backed by native negatives: joint rollback, fractional actual budget, fractional previous budget. The species transition is restricted to charger→root_bell. The first nine-negative candidate and both original source files are retained, each reconstructing its reported source SHA exactly. A green marker from that candidate is not accepted as correctness evidence.

Original CI40993924803 remains failed: parallel48 passed,1 failed,43 unexecuted. Its root-bell audit has the original single non_ecology_content_drift failure; five archived ZIP lengths/SHA values match archived GitHub API metadata. This is not a live API re-fetch and not full167 acceptance. Forest timeout/performance conclusions are excluded.

Guard file SHA256:

- `tests/root_bell_spaces_runner.gd`: `ed2f87c87268c549be92d6598b7c9a0db8dc0472b4e190f9996da025bb8007c3`
- `tools/run_root_bell_spaces.py`: `67695da0014a9d7851be2b4a55483705bf1cb8fdf0479c940a40a7987beeb5dc`

Native report SHA256: `efa3fedf860b3ee74b28646ae01bd58001d48bf68efcb1da0df08d8e72e22a3b`. Native audit SHA256: `9f7b4bed114462fc232e4979a9a2ea992fd5c01d6c6628a9c0c90e137a4149cb`.

Proof: `/tmp/plains_root_bell_coin_guard_final_proof.json`; pure script: `/tmp/review_root_bell_coin_final.py`. The process card is still pending at a5ff; owner must bind its bounded accepted evidence to reviewed_commit2c329. Current tree only has two disclosed archived-job-log newline corrections. This review does not sign full167/affected closure, forest performance, main-task G1–G5/formal, art, audio, GUI, device or user acceptance, and does not retag the older recording.
