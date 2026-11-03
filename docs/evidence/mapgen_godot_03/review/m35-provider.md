# MAPGEN-GODOT-03 M35 Provider independent static review

**Provider/static mapping: ACCEPT for the exact source below. Native/Stage/damage/ride/route behavior remains UNVERIFIED.** There is also a confirmed initial-placement defect in the separately reviewed common-owner WIP, described below; that WIP is not accepted as a playable M35 entrance. No production writes or Godot/browser execution by this reviewer.

Base HEAD5b0b58accf56259928870d2428e8f343dbf211af. Reviewed Provider SHA256 `f4ab815ec0e5a178dbdb6c645c6e6d22c1324a22ae378b80643c1d7347345450`; new Provider runner SHA256 `882562f586ee0f727280ad4b49d4558bde8e15ed3e1a0eb88b0528cba98f545e`. Binding SHA658ede2c388a4b0ddcf6efbcaa85633091b3b42fe7448f080d8d6eacf86ef4bf.

## Actual source cross-check

Read `/tmp/mapgen-v3-m35-audit.md/json`, original reference M35 content and root's actual addon result `/tmp/mapgen-v3-audit/main-project-02/generated.json` (SHA256fb0ca1322590bed1b188c781bc37b72d3365f283215bb54803e158107cc9b853). Actual result is seed930001, fingerprint9a5c671e93a6cbe2a11dde3e54fe2e722810bb5745d694f1b59921f6444639d7. Its complete M35 content equals the independently audited reference as parsed field values; reference file SHA99de30fea7541920ba0d024372927dcee387c7da453916d9e3b05a7093214d1c. This is a source comparison, not this reviewer's generation execution. The new runner itself generates afresh rather than loading this result file.

M35 origin[12,9] becomes only the existing world translation[1536,1152]. Local bounds[0,0,1024,768] and source_affine[1,0,0,1,0,-342] remain metadata/local materialization; no second−342 or mirror transform is added. Original seals are empty; the single selected module does not manufacture neighbors or seams.

The four original platforms remain in order: [0,608,180,40], [620,358,120,40], [320,56,640,40], [960,96,64,24], one-way index2. Full hazard[44,658,912,40] maps to danger_bounds. Saw relay_gear retains origin[512,368], travel[0,240], radius20, period4.8, phase0, damage1 and contact_interval0.7. Ascent_0 retains [250,590]→[550,450]; ascent_1 retains [830,288]→[500,148]; both size120×24, travel3, dwell1.5, phase0. No mechanism is deleted or replaced by a placeholder.

## Strict mapping and native clocks

Provider lines302–320 validates every hazard rectangle and strict eight-field saw, requiring each field's actual type/finite value, native is_valid and full envelope containment. Lines321–338 treats only absent trajectory_kind as the strict original seven-field linear contract; explicit unsupported kinds still reject. Shared IDs reject duplicate saw/ferry and cross-family conflicts. `_definition` lines362–364 preserves hazard/saw/ferry order and instantiates existing ModuleSawDefinition/ModuleMovingPlatformDefinition. New helpers assign every required field explicitly; Resource defaults cannot fill an omitted field. Other unsupported wall/thorn/hook/latch/enemy/reward families remain in EMPTY_FIELDS and are still rejected unless explicitly empty.

No motion implementation is added. Existing ModuleMovingPlatformDefinition retains its9s dwell/travel/dwell/return cycle; ModuleSawDefinition retains origin+travel*sin(TAU*(clock/period+phase)). Existing module clock, ferry and saw nodes remain unchanged: module priority−200 increments one clock, ferry−100 reads it, saw900 reads the same clock and original FrameDamagePolicy1000 handles queued damage. This verifies reuse in source; actual contact, carrying, pause/reload and clocks need native evidence. Static danger_bounds conversion alone does not certify a contact emitter or return/fatal wiring.

Independent byte comparison against5b0 confirms `_ellipse`, `_load_identity`, `_digest`, `_connection_error` and the complete old ellipse validation suffix are unchanged. ROCK-only selected seam admission remains strict, so M35's TOP/ONE_WAY external connection is not newly admitted. Frozen adapter/version remains unchanged; new accepted mechanism data already participates in actual content/load digests. No old accepted identity input was intentionally altered, and no old-M35 acceptance is claimed because it was previously refused.

## Runner coverage and limits

The new runner reads actual installation/input hashes and the independent M35 binding, invokes the source-owned real addon job and Provider, then inspects the taken Plan without creating a Stage or committing. It checks single-module/no-neighbor inventory, exact translation/bounds, hazard/saw/linear fields, native boundary times, unchanged result data and original definition support. Valid hazard/saw/linear modifications must change identity and reject old state. It deletes every required saw/linear field and probes unknown/nonfinite/zero/duplicate/cross-ID/phase/envelope errors and remaining unsupported families.

These are meaningful data-admission tests; the expected geometry comes from the audited original values, not a duplicate solver. They do not exercise static hazard damage, saw sweep, two physical rides, respawn, pause/reload, safe entry or teardown of an actual M35 Stage. The runner preloads the author-owned M35 source for binding constants; that new source/Stage was WIP and is not signed by this Provider review. No actual new Native result was supplied/run at this review point.

## Confirmed common-owner WIP defect: initial placement refused while inactive

Read common slice SHA `b8a586bf49b8b85e1eb5fe8ad3a51de5ebd8c65b3b8b2363c40d49a7f248e55a` and generated source SHA `03ab5566b7a7d377a6da5438a549d99ad4e820d455ffa77c78a3b90eee3c2fca` for provisional control-flow audit only.

Generated `_start_source` disables controller activity while loading. Common `_assemble_plan` lines81–82 calls `controller.return_to_segment(plan.spawn)` and ignores its return. PlayerController lines253–255 explicitly refuses that call when inactive. Generated `_finish_install` only later sets active=true; it does not perform the refused placement. Therefore a safety check at the candidate binding point can succeed while the actual player remains at its prior coordinates. The earlier retained slice02 loaded observation at[0,0] is consistent with this exact call chain, not proof of the new hook's runtime outcome. Reported immediately to root and binding_closeout; root owns the common-owner fix. The M35 subclass does not conceal the defect with an extra physical move.

Required resolution is an explicit owner-controlled, one-time initial placement with checked success after actual safe admission and before readiness, without changing Motor or adding per-frame teleports. A new runtime counterexample should verify actual player position equals admitted spawn and that a rejected unsafe/closed/stale source never activates or commits.

The new pending-build hook otherwise checks current handle/lifetime before assembly, before physics admission and again before commit; close clears pending build and closes the envelope. It waits for a physics callback before the optional safety hook, keeping controller inactive/readiness false; no pre-registration query is made in the render assembly path. SegmentRespawn performs real shape-overlap and three-foot-ray checks. Actual PhysicsServer registration timing must still be validated natively; the static ordering is not a substitute. Failed/stale paths detach the provisional Stage/policy. No late/duplicate successful commit path was found in that provisional source, but no WIP Stage/owner acceptance or complete resource-release claim is made.

Provider verdict remains limited to f4ab815e and its data tests. Common-owner initial positioning must be fixed and the new native scope actually run before signing M35 gameplay entry. Whole-map/M24/adjacent routes/Web/mobile/FPS/user acceptance remain outside this report.
