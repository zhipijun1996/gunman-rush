# MAPGEN-930001-01 independent review

Reviewer: `/root/review`, separate agent from the registry/host, Boss binding and test authors. Scope: fixed delivery `0.1.0`, seed `930001`, branch `feature/mapgen-delivery-930001`, base `840108da9ae91e412dc9f1d8a38ccdad0229bb11`. This review is static/read-only; the root agent owns the only Godot execution lease. It is not independent runtime, GUI, human or device certification.

Current verdict: **ACCEPT for the documented scoped integration; complete-map delivery remains BLOCKED / unverified**. The final root-owned acceptance-04 run has 721 checks: 718 passed and three strict failures, all caused by the preserved M24 reward/Seal_C conflict. It has no native script/resource exit diagnostics and an unchanged 3,376-file runtime source snapshot. Continuous whole-map traversal is explicitly NOT_RUN. This is independent source/artifact review, not independent Godot execution, browser operation, user or device approval. Earlier findings and failures remain below as history; the final re-review at the end supersedes their pending repair statuses.

## Positive static findings

- Independently recomputed all 721 manifest file hashes: zero mismatches, zero missing files, zero extra files inside `third_party/mapgen/0.1.0`. The `.gdignore` sits in its parent. Original module sources remain byte-identical.
- `materialized_registry.gd` inspects source PackedScene script identity without instantiating that scene. The adapter receives `materialized_content` before tree entry; its overridden `_ready()` builds one terrain graph. Instance placement consumes only `origin_blocks * 128`, including negatives. No second mirror, source affine or scene origin offset is applied.
- Native loader inheritance retains the selected module mechanisms, enemies and rewards. Native enemy/damage IDs include encoded run/map/instance identity; native SimpleRoomReward definitions include that same scope. The ordinary repeat-module coin grants therefore do not share wallet transaction IDs.
- Terrain construction preserves one-way indices, wall indices, hazards, thorn face/offsets, saws, native linear/polyline ferry definitions and native mechanism installers. The separate materialized ellipse class consumes `ellipse_x_sign` while keeping the native symmetric envelope and timing.
- All declared seals have their final local delivery rectangles used as actual StaticBody collision. Seal damage is not invented.
- M40 uses BossFactory's existing `windkeeper_storm`. The adapter derives shelf standing points from actual materialized slabs, and native combat/health remains authoritative. Phase 3 disables original Platform0 collision before adding the two lifecycle shore bodies; it does not duplicate the initially loaded floor. Original slabs/Platform4 and the initial exit seal remain. Native policy ends the lifetime before same-frame fatal batch consumers; victory checks that lifetime and player health after batch resolution.
- The host config explicitly records an interior M01 spawn rather than the sealed entry, grants the existing grapple ability once at creation from delivered route requirements, and does not mutate PlayerTuning. Initial creation and environmental SegmentRespawn are distinguished from ordinary seam traversal.

## Findings sent to implementers

### R1 — M29 hidden helper consumes outer game input (high; static confirmed; code fix present, runtime pending)

The vendor `original_pickups_v4` and `original_region_chests_v5` construct hidden `PickupApp`/`RegionApp` subclasses. Their `_ready()` suppresses normal DemoApp setup but leaves inherited `_input()` enabled. `DemoApp._input()` dereferences the unconstructed `menu` on Escape/gamepad Start; M invokes map UI APIs with null map controls. Since M29 is always loaded, this affects every room.

Root has added `set_process_input(false)` to both hidden apps after native binding. That is the appropriate adapter boundary: the map owns global input while StageRewardModal keeps its own GUI input. Actual M/Escape and chest GUI tests are still required; source inspection is not a runtime PASS.

### R2 — reward modal and map pause ownership conflict (high; original static counterexample confirmed; source fixed, runtime pending)

`fixed_map.gd::_unhandled_key_input()` toggles `_paused` / `_map_view` without considering the native M29 chest modal. Native `_region_interact()` pauses the tree while the map's booleans remain false. Two Escape presses, or M followed by M, make `get_tree().paused = false` even though the mandatory native reward modal remains open. The player can receive new actions behind a visible choice UI.

The host now checks `_native_reward_modal_open()` before global map/pause/new-run/title actions. Static re-review accepts this ownership guard. Actual choice completion, immediate first-move behavior and real key events with the modal open still require native execution.

### R3 — same-run reload loses reward-driven gate state (high; original static counterexample confirmed; bounded source fix, runtime pending)

`materialized_registry.gd::unload()` frees the module without preserving native `export_saved_state()`. Reinstantiation recreates reward services and the initial paired gate. In M43/M44/M46 (`idea-plains-hq04-001`) `revision059_reward_pair::accept_reward()` only reacts to `SimpleRewardResult.COMMITTED`. The shared wallet correctly refuses a second coin grant by replaying the old transaction, so no new COMMITTED signal occurs and the reward-driven gate never restores its switched state. Ordinary claimed sprites/services also initially reset.

The registry now captures native `export_saved_state()` and passes `provide_saved_state()` before binding. It also restores ordinary claimed services/receipts/sprites while checking exact lifetime/wallet/player/content scope. Unsupported complex/enemy/moving/Boss/native-chest unloads explicitly fail and retain the live instance. This bounded policy prevents silent resets; it does not implement general streaming or process-level save/resume. Add native same-run reward/gate reload tests, including repeat-module independence. No normal seam unloads a module, so the original defect was a reload-path defect, not evidence that seam traversal reset resources.

### R4 — original M29 native chest is a separate acceptance consumer (coverage; runtime pending)

The 11 `reward_sites` do not include M29's native `original_region_chests` entry. It offers the existing OR choice of 4 coins or 1 note. A scoped native interaction/actual modal selection must check shared wallet/meta, claimed state, duplicate refusal, and immediate input resumption. This cannot be inferred from the other 11 coin reward probes. The test author is adding this coverage.

## Explicit review limits

No Godot process was run by the reviewer. Fixture placements/test_move sweeps are scoped diagnostics; they cannot certify continuous routes or that the three main paths can be completed with the actual remaining resources and mechanism phases. Native controller/shot/Boss tests, screenshots, whole-map continuous progression, browser export/GUI, devices, player fairness and enjoyment remain separate evidence. Reported failures must retain concrete instance/module/Port or host API details and their original logs.

### R5 — Resource.duplicate discarded mirror sign (high; observed root runtime failure; code fix present, rerun pending)

The first adapter declared `ellipse_x_sign` as an ordinary GDScript property. `PlatformingModule._ready()` deep-duplicates its Definition Resource, which does not preserve that unstored property. The root-owned `all-dev01.json` records M16/P actual `[420.691,144.091]` versus materialized expected `[217.690,145.287]`; the same reversal appears in M38. This is a real mirror adapter defect, not invalid delivery geometry. The source now exports the sign and materialized center/radii through storage properties. Re-run live phase sampling after duplication before accepting the fix. The reviewer read the original raw runtime record but did not independently execute it.

## Diagnostic test interpretations sent to the test author

- Expected one-way indices must be normalized to integers after JSON parsing. Comparing an integer test index against the JSON float Array produces false negatives even though the actual native shape is one-way. Keep the actual shape assertion; correct the independently read numeric representation.
- `reward.position` is a chest anchor, not a complete-body player spawn. For example M41 has chest `(48,148)` above a one-way support top160; the 36px-tall player's standing center is142. Placing center148 begins inside the support and can drop through. A clearly labelled fixture should start above the real support, then let native gravity land and claim; natural route access remains unverified.
- The failed downward seam sweeps at C003/C008/C011/C015/C021/C025/C029 hit intended one-way tops. This alone cannot establish an impassable connection: actual native drop-through input must be tried.
- Several bottom-seal probes first hit another one-way support (M07/M08/M12/M16/M31). They demonstrate a blocked sweep, but not that the named seal itself was the collider. Independently check the seal's collision RID/shape and preserve the full-world test.
- The first Boss pilot deliberately aimed from the shelf center while repeatedly jumping. Shots aimed down through a one-way shelf can legitimately be blocked. Retain its no-damage/player-death failure and collect actual impact/target receipts before attributing that result to the Boss binding.

These are interpretation corrections, not authorizations to lower physical thresholds or replace real player traversal with geometric proofs.


## Latest re-review: root-owned acceptance-03

Source inspected again after the input dispatch/cooldown/native-chest test corrections. The root runtime report is `build/mapgen_930001/acceptance-03/runtime.json`, SHA-256 `4aca6abc74fa4cedef02edc5c110d53a25acff76493f6ee372776f0a6495cd47`; its actual result is 721 checks / 8 failures, wrapper status failed, source_stable true. This is a read of an actual separately executed artifact, not independent reviewer execution, and is not the final source rerun after later changes.

The three proposed test corrections are legitimate:

- `Input.flush_buffered_events()` observes the native key event after dispatch instead of reading its axis while still queued. It changes neither accepted action requirements nor the host controller.
- Waiting 30 native frames before the spawn shot lets the prior fresh-control shot cooldown expire. There is no resource reset, refill or extra actor.
- Removing a grounding requirement from the M29 W-offer assertion matches the original `DemoApp._can_interact()` / `_region_interact()` consumer, which requires live lifetime/health, distance and pause eligibility but does not require a grounded player. The test still requires the actual W dispatch, both original choices and modal pause. It reports the actual airborne state.

These changes need their actual final rerun; they do not retroactively turn the five corresponding acceptance-03 setup/checker failures into PASS. M24's three failures remain strict failures rather than expected-failure exemptions.

Observed scoped evidence in acceptance-03:

| Consumer | Observed result | Limit |
| --- | --- | --- |
| Connection sweeps/direction plus seven actual descent/drop cases | 179 recorded seam cases passed | Most are full native body sweeps, not continuous player routes |
| Gear seals | All 40 exact seal collision cases passed | Either-direction exact collider evidence; no invented damage |
| Moving platforms | All 90 live phase samples passed, including mirrored M16/M38 ellipses | Three samples per body, not all mechanism phases |
| Compiled reward sites | 10 of 11 claimed through the real native player/transaction, including all six target rooms | Diagnostic initial positions; no natural route certification |
| Same-run M41/M43 | Claimed state and HQ paired gate restored, wallet unchanged; wrong-wallet scope rejected | Complex/enemy/moving/Boss/native-chest unloads are explicitly refused and kept live; general streaming/resume unsupported |
| M29 native chest | Original coin4 OR note1 grants and duplicate/other-choice refusal passed in separate runs; modal kept pause ownership | Choice used the declared native API, not actual mouse/touch card selection; W offer grounding assertion was the original incorrect failure |
| M40 native Windkeeper | Actual 36 accepted shots, HP36→0, phases1/2/3, player HP5→3, victory ended lifetime | Initial arrival was a labelled position fixture; no teleport/grants during combat; not whole-map arrival |
| Boss exit / death priority | Exact exit seal still blocks after victory and cancellation; same-frame player death suppressed completion | Same-frame negative is a direct-policy transaction fixture, not natural simultaneous combat |

### R6 — M24 reward blocked by declared Seal_C (high; concrete physical incompatibility)

M24 is `idea-orbit-choice-001`. Its gear Seal_C `[256,0,128,32]` covers the only support `[288,32,64,16]` within reward region `[300,-10,80,56]`. For the unchanged 24×36 body, standing on that support needs center y14, which overlaps the seal. Standing on the seal itself requires center y−18, outside the claim region's lower bound −10. A body outside either seal side cannot remain inside the claim region while supported. The moving carrier's highest center y176 cannot supply this high claim stance.

The actual report independently queries full native body collision at candidate support positions and names `/root/FixedMap930001/M24/Seal_C` for every rejection. It retains reward.claimed=false and zero coin grant. The aggregate 11-site identity check also remains failed because only ten sites were claimed. This is not cured by M24 being outside the six target rooms. Do not move/remove its reward, alter the seal or add a Route under this task's restrictions. Keep the concrete upstream geometry conflict as a remaining gap; complete-map acceptance is rejected.

### R7 — strict exit resource leak remains unresolved (high; root log observed)

The root-owned reward-isolation logs report 74 ObjectDB instances and 61 resources still in use at exit even when the lifecycle/audio assertion itself passed. `tools/run_mapgen_delivery_tests.py` correctly rejects those native terminal errors. A zero-failure marker inside a narrowed consumer does not override them. Root is isolating whether the surviving ownership belongs to the test coroutine/source or integration. Do not sign a clean lifecycle until the cause and a same-scope fresh run are demonstrated; retain the original logs.

### Export and UI additions

The new editor export plugin statically verifies the exact pinned delivery manifest and each original file before adding all 722 original byte streams to the PCK; it also adds the host config. `project.godot` only enables this plugin beside the existing raw exporter; its main scene/physics remain unchanged. Actual exported PCK hash verification and runtime loading are still required before Web delivery is accepted.

The host adds existing TouchOverlay pause/new-run bindings and explicit action buttons; they call the same guarded host actions. Native card choice and those pointer/touch controls still need real GUI evidence. Static wiring alone does not certify a usable browser/mobile flow.

The immutable delivery tree was rechecked after these changes: 722 files total, all 721 declared file hashes match, zero extra/missing files. No original module or materialized content was edited to hide R6.


## Final scoped re-review: acceptance-04

Artifacts independently read from `docs/evidence/mapgen_930001/acceptance-04-{report.json,runtime.json.gz,native.log.gz,source-before.json.gz,source-after.json.gz}`. Decompressed runtime SHA-256: `fb579ea1efe55ab97cc0e22312b699cf8c592ce54a5ecc1ca4a6409afcb545a1`.

- Actual result: **721 checks, 718 passed, 3 failed**. The only failed IDs are `reward/supported_fixture/M24/reward`, `reward/physical_claim/M24/reward`, and aggregate `reward/instance_isolation`. They remain ordinary failures and the wrapper remains failed/exit1. This is faithful failure reporting, not a whole-map PASS.
- Independently decompressed both source manifests: 3,376 entries each, identical before/after. Recomputed every listed hash against the current working source: zero differences. The reported source commit is the baseline because the measurement was on the then-uncommitted implementation; the exact measured bytes are the source manifest, not an invented clean-head claim.
- Independently scanned the complete native log: no SCRIPT/SHADER/native ERROR, ObjectDB leak or resources-still-in-use diagnostic. The only nonzero outcome is the three retained M24 assertions.
- Native fresh D dispatch and fresh mouse release now pass. The spawn remains at the validated interior `(approximately95.76,206)`, the real shot opens M01's bell once, and the unchanged real player walks through C001/M01.exit→M02.R to x542.38 with HP5 unchanged. These are continuous native inputs without fixture repositioning.
- The acceptance-03 scoped results for all seals/seams, all moving-body samples, ten actual reward claims, all six target rewards, M41/M43 same-run restoration, wrong-wallet rejection, native M29 OR transactions, native Boss combat and death priority remain present and passing. M29's actual W offer also passes after the valid contract correction. Native card choices still use the declared choice API and are not a GUI mouse-choice certificate.

### R7 resolution: test load ownership, no production teardown change

Inspected the correction: `tests/mapgen_delivery_tests.gd` now preloads the same fixed PackedScene into `FIXED_SCENE` and instantiates that Resource for initial test setup. It does not modify production actor cleanup, disable diagnostics, change the engine, remove native objects from the report, or weaken the wrapper's strict exit guards. The direct `reward_direct.gd` claim log was already clean; the lazily loaded inherited test isolate `claim-no-reload.log` leaked 74 ObjectDB instances/61 resources; the matched `claim-preload.log` performs the M41 and M43 claims with the same inherited helper and exits clean. The final full acceptance-04 log is clean too. This supports the bounded test scene/script load-ownership correction. It does not retroactively erase the earlier leaks or claim a general engine root cause beyond that tested load path.

### Actual PNG review and reference comparison

The reviewer opened the actual root-captured `spawn.png` (SHA-256 `9e8b3ac8b0a2984943322b8c3c0f6f1dd74be1e75f07ab4063997aa6f5b37621`) and `overview.png` (SHA-256 `34b4cf6edeafafaf22a547d9c4d564fd8a9d2988fc060119872294d99bab6d7d`) and the immutable delivery reference PNG. The actual spawn visibly uses the main player's artwork on M01's floor, with the sealed left entry and native bell/gate to the right. The actual overview matches the reference's broad module placement, negative-coordinate upper-left Boss chain, outer reward branches and lower loop; there is no second mirrored terrain layout. This is a limited layout/capture review, not pixel-perfect terrain equivalence, normal-speed animation, sound, performance or full-route certification. The capture log identifies software Mesa/llvmpipe and records its V-Sync warning.

### Final acceptance boundary

**Scoped integration is accepted** for faithful materialized construction, original package/hash preservation, shared existing player/services, instance identities, validated initial spawn and first seam, exact seal collision probes, sampled mirrored motion, tested native reward transactions/restoration and scoped native Boss defeat/end-of-run ordering. Relevant source fixes R1–R5 are supported within those recorded cases.

**Complete map acceptance is blocked** by R6/M24. The user forbids moving the original reward, altering its seal, fabricating Routes or changing player physics; those restrictions were respected. Whole-map continuous navigation, the three complete main routes with carried resources/phases, natural reachability of all rewards/Boss, all dynamic mechanism states, actual browser/pointer/touch choice flow, physical devices, performance and user judgement remain unverified. Keep this seed and its failure visible; do not expand to batch maps or in-game generation as though first-map end-to-end acceptance had passed.
