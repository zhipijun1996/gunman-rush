# Original formal consumer rerun · final narrow resolution

Root's original strict wrapper rerun `build/plains-revision-formal-02.log` now contains `ENEMY_FEEDBACK_01_FORMAL checks=66 failures=0`, actual audio drain, and no script/shader/ObjectDB/resource/RID/consumer-failure output. Complete log SHA256 `37fd125b66ea970c8df9200c4aa333d34f9dde329293d95c8bb11a7c6cd76b3e`. Root reports clean command exit; reviewer independently read the complete log but did not launch Godot. This resolves the observed migrated-test dependency leak for this consumer. Original failed formal01/verbose and first partial probe remain failed and retained.

The actual repaired edge is the test helper's nested inferred revision and frame properties: current helper uses Object.get→RefCounted/runtime calls while retaining exact new concrete script identity and real finished/rig/source/bounds checks. The earlier RootBellPulseArt hypothesis was disproved and withdrawn. This narrow resolution does not sign visual quality, natural gameplay, full Release, user or device acceptance. Current committed code/guard review is separately `/tmp/plains_revision_code_review_r2.md` for4ff79069628776ac489e3344cd3e49d390a4db56.

---

# Final load-only edge removal · R4 observation

The second dynamic helper probe log `build/plains-revision-formal-dynamic-load-probe-02.log` now reaches normal XR shutdown with **no ObjectDB/resource/RID or script/shader errors in the complete log**. SHA256 `f6a0b62bb810b2cee37ef31cb43caddf533fc57e280b2abb3b9edbf54820b205`. Both new-rig and old-Frames branches now observe their actual source/pose through Object.get/RefCounted and runtime calls; final rig identity/source/bounds/finished checks and old final-frame source/bounds checks remain.

The controlled difference is the migrated formal test's nested typed property/method access. RootBellPulseArt and production instance cleanup are not the cause supported by these controls. This is a clean **load-only log observation**, not an independent gameplay execution or a completed formal result. The root-owned original wrapper rerun `build/plains-revision-formal-02.log` was still in progress when this note was added; its final strict result must be recorded separately. Original formal01/verbose and first partial dynamic probe remain failed.

---

# Controlled load-only probes · R3 diagnosis update

The new actual controls narrow the failure to **test-script compilation/type resolution in the migrated `actual_final_body` helper**, rather than the live Visual constructor, Node teardown or RootBellPulseArt. Root performed the probes under the single engine lease; this reviewer independently read their original logs and helper diff, without launching Godot.

- Dynamic load/release `PlainsRevisionVisual` without an instance: clean.
- Dynamic load/release the migrated formal test, no instance or gameplay: reproduces the same52 ObjectDB/32resources.
- Load baseline pre-migration formal source from `/tmp` against the **same current production source**: clean.
- Replace the new helper's nested revision rig type inference with Object.get→RefCounted and exact runtime script identity/source/bounds checks: revision dependency graph removed, but first follow-up still fails16 ObjectDB/8resources/4textures. The remaining identities are the old Frames four PNGs, EnemyFeedback01Frames, EnemyFeedback01 and damage-feedback resource/script. This is partial localization, not a clean result.

The still-typed old branch `art.feedback_frames.texture(7)/bounds(7)` is the next controlled edge to remove through the same runtime observation, preserving the real final frame/source/bounds checks. The new rig branch checks exact `plains_revision_remains.gd` script, final reporting index7, `_finished_death`, same captured rig, same actual mother texture and fixed bounds. This is a loading-dependency repair to the test consumer, not replacing production assertions with fake metadata. Keeping an exact script-path check is at least as strict as the previous `is PlainsRevisionRemains` class/subclass test for this finite implementation.

The Visual-static-self-constructor hypothesis is also not supported by its clean standalone load control. Earlier hypotheses remain below as the honest diagnosis trail, not authoritative current root causes. The exact compiler retaining edge cannot be called confirmed until the last probe and original full formal wrapper pass cleanly. No timeout, assertion count, shutdown guard or production gameplay should be weakened.

Probe receipts read by the independent reviewer:

```json
{
  "visual-load": {
    "path": "build/plains-revision-visual-load-probe.log",
    "sha256": "12f711ea28b2b66acddeb2967c342c2e3d792a5ee6560cef2bd2bfcae453b2e8",
    "leak_lines": [],
    "resources": []
  },
  "formal-load": {
    "path": "build/plains-revision-formal-load-probe.log",
    "sha256": "a4f1dfb46b36a32d750d6a1a9fab63c36da78a2985c73b67ce1a2b7d4df9e2d0",
    "leak_lines": [
      "WARNING: 52 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
      "ERROR: 32 resources still in use at exit.",
      "ERROR: 10 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit."
    ],
    "resources": [
      "res://scripts/damage/damage_feedback_definition.gd (GDScript)",
      "res://resources/damage/feedback.tres (Resource)",
      "res://scripts/resources/contracts/actor_resource_result.gd (GDScript)",
      "res://scripts/resources/state/actor_resource_state.gd (GDScript)",
      "res://scripts/resources/state/health_state.gd (GDScript)",
      "res://scripts/combat/damageable.gd (GDScript)",
      "res://scripts/audio/game_audio.gd (GDScript)",
      "res://scripts/enemies/enemy_actor.gd (GDScript)",
      "res://scripts/enemies/enemy_feedback_01.gd (GDScript)",
      "res://scripts/enemies/enemy_feedback_01_particles.gd (GDScript)",
      "res://scripts/enemies/enemy_definition.gd (GDScript)",
      "res://assets/enemy_feedback_01/frames_v8/underworld_charger.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/underworld_diver.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/legacy_charger.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/legacy_diver.png (CompressedTexture2D)",
      "res://scripts/enemies/enemy_feedback_01_frames.gd (GDScript)",
      "res://scripts/enemies/enemy_feedback_01_flash.gdshader (Shader)",
      "res://scripts/enemies/plains_motion_02.gd (GDScript)",
      "res://scripts/enemies/enemy_feedback_01_remains.gd (GDScript)",
      "res://scripts/enemies/plains_revision_skin.gdshader (Shader)",
      "res://assets/plains_revision_01/patrol.png (CompressedTexture2D)",
      "res://assets/plains_revision_01/charger.png (CompressedTexture2D)",
      "res://assets/plains_revision_01/hopper.png (CompressedTexture2D)",
      "res://assets/plains_revision_01/sentry.png (CompressedTexture2D)",
      "res://assets/plains_revision_01/fan_sentry.png (CompressedTexture2D)",
      "res://assets/plains_revision_01/root_bell.png (CompressedTexture2D)",
      "res://scripts/enemies/plains_revision_ground.gd (GDScript)",
      "res://scripts/enemies/plains_revision_flora.gd (GDScript)",
      "res://scripts/enemies/plains_revision_skin.gd (GDScript)",
      "res://assets/audio/plains_revision_01/root_bell_fall.wav (AudioStreamWAV)",
      "res://scripts/enemies/plains_revision_remains.gd (GDScript)",
      "res://scripts/enemies/plains_revision_visual.gd (GDScript)"
    ]
  },
  "formal-old-load": {
    "path": "build/plains-revision-formal-old-load-probe.log",
    "sha256": "cfb62adbd231504926b9908ef3fd460e2a1b852a4a413325dbd9d60ee12c0e62",
    "leak_lines": [],
    "resources": []
  },
  "formal-dynamic-load": {
    "path": "build/plains-revision-formal-dynamic-load-probe.log",
    "sha256": "ad3b8bc37b1e07cec05cb3ce60dd5ad2664bbf2738409dcd6f631c705a0e56b3",
    "leak_lines": [
      "WARNING: 16 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
      "ERROR: 8 resources still in use at exit.",
      "ERROR: 4 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit."
    ],
    "resources": [
      "res://scripts/damage/damage_feedback_definition.gd (GDScript)",
      "res://resources/damage/feedback.tres (Resource)",
      "res://scripts/enemies/enemy_feedback_01.gd (GDScript)",
      "res://assets/enemy_feedback_01/frames_v8/underworld_charger.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/underworld_diver.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/legacy_charger.png (CompressedTexture2D)",
      "res://assets/enemy_feedback_01/frames_v8/legacy_diver.png (CompressedTexture2D)",
      "res://scripts/enemies/enemy_feedback_01_frames.gd (GDScript)"
    ]
  }
}
```

---

# Verbose evidence correction · R2 diagnosis

**The previous highest-priority RootBellPulseArt/static-manifest hypothesis is contradicted by the actual verbose resource identities and is withdrawn. It was a hypothesis, never a confirmed root cause.** RootBellPulseArt and its burst atlas are not among the 32 leaked resources. Do not use that hypothesis to justify a production patch or acceptance.

Actual follow-up log: `build/plains-revision-formal-verbose-01.log`, SHA256 `563df3ecdd87d83b0633fe5b22ca1e6701ca834b93f5bcfe78f92cdaf4a034c8`. The 52 leaked ObjectDB entries are GDScriptNativeClass/GDScript plus Image/Texture/Shader/Audio resources; **no live Visual/Remains Node, concrete RefCounted instance or ArrayMesh instance is listed**. The 32 resource paths include PlainsRevisionVisual/Skin/Ground/Flora/Remains, six neutral PNGs, the old four Frames PNGs, both shaders, the low bell WAV, and their Actor/Health/feedback/audio script dependencies. This is evidence of a retained script/resource dependency graph, rather than evidence that stage Nodes or a mesh instance survived unload.

The exact retaining edge is still UNVERIFIED. Source inspection has no clear Skin→Visual or Remains→Visual backward dependency: the instance view Callable is cleared by dispose, and Nodes are explicitly freed. A candidate to isolate is the dynamically loaded Visual script's static constructor returning its own class type and calling `PlainsRevisionVisual.new()`, or a transitive GDScript class-resolution/cache dependency. Both clean native consumers directly type/cast the revision classes at top level, while formal reaches them through Underworld/dynamic assembly; that loading-context difference is a useful controlled comparison, not proof of a compiler bug.

Root alone is executing independent `/tmp` minimal probes under the sole engine lease: Visual load/release without instantiation; Skin load/release; Remains load/release; then instance/install if needed. Preserve every probe's verbose identity list. No repair is accepted until the exact original formal consumer passes its unchanged shutdown guard cleanly. The original66/0+leak remains FAIL.

---

## Earlier read-only hypothesis and why it was superseded

# Formal exit leak · independent read-only diagnosis

Status: **formal run FAIL**. The `ENEMY_FEEDBACK_01_FORMAL checks=66 failures=0` marker does not override leaked resources. No Godot process was launched by this reviewer and no production/test files were changed.

Observed original log: `build/plains-revision-formal-01.log`, SHA256 `5dbbcf5e6bae5c09325e44f2cd00f4e967b23ecb8f1edbb8d2da14de18bdc8ad`. It reports 52 ObjectDB instances, 32 live resources, 2 DummyShader RIDs, 10 DummyTexture RIDs and a VariantPools BucketSmall allocator leak. Audio ownership teardown says released=true; the formal test checks old stage/corpse WeakRefs and full app unload, but those checks do not prove GDScript/static resource unloading.

## Highest-priority cause to falsify

The newly introduced `RootBellPulseArt` is a RefCounted script called statically from both PixelPlainsEnemy and RootBellPresentation. The observed source declares `const ATLAS := preload(...)` and `static var _manifest: Dictionary = {}`, filled on the first actual pulse draw. There is no owner instance/dispose path for this static storage. A static-initialized GDScript can keep its script/dependency graph resident, retaining preloaded textures and shaders; this fits resource-only tail leakage better than a live-body rig cycle. The native lifecycle fixtures may never execute a real active root-bell draw, whereas formal combat does.

This is a **code-based hypothesis**, not yet confirmed by verbose ObjectDB identity output or a rerun. Current pulse-helper source SHA when this note was saved: `0ae67e929ec01c91a0cef674578d417a0db5408a326aa6301e35b7aab5f1baf0`. If root already edits it, use the failed run's original snapshot/source as the authority, not this later hash.

## What the instance graph suggests

Visual→Remains references are Nodes, freed explicitly; Remains.dispose clears `_view`, `_rig`, `_captured_pose`, then the base disconnects receiver/health/host callbacks. Lifecycle.dispose disconnects its HealthState callback, owns sample disposal, and clears motion/callback state. Samples likewise disconnect their HealthState callback. A persistent mesh-instance cycle would be expected to retain ArrayMesh instances too; the nonverbose log only names Shader/Texture RIDs, so a static script resource graph currently looks more likely. This does not exonerate the instance graph without verbose identities.

## Strict counterexamples / minimal verification

1. Run the exact formal consumer with `--verbose` under root's sole engine lease. Preserve its original failure and list leaked instance/resource paths. Look for root_bell_pulse_art.gd, its burst atlas, six new neutral PNGs, skin/flash shaders and dependent GDScripts.
2. Remove static ownership of the cached manifest: a finite explicitly owned renderer cache, or a manifest constant/plain call-local parse if appropriate. `@static_unload` is another diagnostic candidate, but needs actual Godot 4.7.2 teardown verification; do not assume it fixes the leak.
3. Rerun the same formal consumer with all 66 or subsequent added assertions intact and original timeout. Require clean log/exit and no shader/texture/ObjectDB/resource leak. Native clean results alone cannot certify it.
4. If failure persists, compare the exact leaked identities before/after. Then inspect callable/signal ownership on those actual RefCounted instances; do not disable shutdown checks or add an arbitrary sleep to conceal live references.

No ACCEPT or visual conclusion is issued here. The original formal failure remains part of the evidence chain.
