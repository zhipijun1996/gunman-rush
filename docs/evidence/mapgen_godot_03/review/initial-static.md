# MAPGEN-GODOT-03 Provider / job / request independent static review

Verdict: **ACCEPT for the final reviewed static scope; runtime outcome remains UNVERIFIED.** Reviewer: death_event_audit, non-author of these three files. Read-only source audit; no Godot/browser execution or production changes. Only this external report was written. This does not certify complete-map playability, physical reachability, mobile behavior or frame-time performance.

Reviewed WIP over HEAD `e7d703f47c97f09bd5c5d48e24f0a400c958ad40` in `/tmp/gunman-rush-mapgen-03`:

| File | SHA256 |
|---|---|
| game/world/levels/providers/runtime_map_v2_provider.gd | 16ee5d9d9ab86d493e684bb03aff6bdfdc90871534282a2f633476a3bbe8c6cb |
| experiments/generation/runtime_map_generation_job.gd | 28c7a42b6b745b0cac6fedb3843d0bb39b26c289da8d4925db935b09db6ec25d |
| experiments/generation/runtime_map_generation_request.gd | fcf5bc7f47582e1f381f48e3329b30bcade4863286000f1b7fa769569297b653 |
| config/mapgen_candidate.json | d8271d473686fd1e7b0bcfab280aa2940777eb1eaa02478b80909cb8eecae92f |

## Found and corrected during review

The initial job SHA `e195982e1c7ff5e4ccfbb39cb08b78f4cd116dc985c35ba851648c6a353879d6` returned its actual internal Ticket. Public mutable fields exposed phase/token/request/result and defeated the opaque-handle boundary. Reported immediately to root and binding_closeout; the author fixed it. **Final SHA28c7a42b passes this re-review:** internal Ticket owns a separate plain RefCounted handle (lines10–12); begin returns only that handle (69). Public `_ticket` uses exact current handle identity and serial (172–174). Internal `_accepts` takes Ticket directly; no mistaken public-handle lookup remains in begin/guard/commit/result/provenance. Finding is resolved for this frozen SHA; the original failure remains recorded here.

## Provider: old identity preserved, generated source explicit

Compared all17 pre-existing helper bodies against HEAD: byte-exact, including `_load_identity`, `_digest`, geometry/port validation and conversion. Existing constants and frozen identity schema/adapter version remain unchanged. Frozen `load_level` delegates to the shared converter with an empty generated result; its original byte-attestation checks, identity function and validation order remain selected. No intentional frozen identity input or arithmetic changes were found. This is static equivalence evidence, not an independently executed old-hash oracle.

The separate generated entry validates PASS/schema, finite JSON-only payload, implementation/algorithm, captured request/config and exact integer seed, map/result/captured fingerprints and module identity before the same converter. Unknown provenance fields (including fake `files`) are rejected. The generated path supplies no invented map byte SHA. Its identity explicitly says generated_memory, hashes the actual complete generated map/content store and actual bindings using the existing sorted/full-precision encoding, and includes actual algorithm-package/module/archive identity and host selection/binding/spawn/capability values. Result timing/diagnostics remain visible through a separate result receipt digest rather than perturbing restore identity. No upstream fingerprint or map_id assignment/mutation occurs. The generated Provider trusts captured provenance rather than independently recomputing the addon's canonical fingerprint; the job does that recomputation using original Protocol.

Config lock identities were checked for correct roles: release93c5221a…; package source508b558e…; candidate archive9ea87854…; module1.1.0 ZIP5ad5a787…. The job reads these from the installation lock and checks protocol/module expectations. Addon script byte verification remains installer/bundle responsibility, explicitly documented in the code; this is not a runtime signature/authenticity verifier.

## Job: lifetime, stale/duplicate/exit and synchronous boundary

Final begin deep-copies request data/config/bindings/IDs and LevelRequest capabilities/tuning, captures a token from the explicitly supplied lifetime, and holds the owner weakly. It cancels/replaces the previous internal Ticket and assigns a new object-identity handle/serial. Every result-accepting operation checks the caller's actual current lifetime object, not only equal epoch numbers; the token must still be accepted and owner must remain valid/not queued for deletion (127–133). Old/foreign/fabricated handles fail `_ticket` without cancelling a replacement. Current stale lifetime/token invokes cancellation. Closed envelopes reject begin/tick/take/commit/result/provenance.

Take requires ready and succeeds once; it consumes the stored build and enters assemble. Commit requires that taken assemble phase, transitions once, and checks the same current envelope. Duplicate take/commit, cancelled/failed/closed results cannot commit. Abort/fail-assembly act only on the current handle and cannot resurrect or accept a result. Public diagnostic Dictionaries/arrays are detached copies. Close/cancel clears job/library/built references; this does not assert all retained result/diagnostic memory is released until the envelope itself is released.

Wrapper tick has no await, SceneTree or Node creation. It calls original cooperative `advance` synchronously with validated1..4096 operation budget, then rechecks the envelope. Original addon advance resumes its private credit continuation through its own signal; it does not depend on SceneTree frames or a worker. Preload performs synchronous file/archive work, and validation/deep copying may also take a long frame: operation counts do not establish a millisecond bound. Actual assembly/cleanup scheduling remains entrance responsibility; no finished entrance integration is signed here.

## Request builder: reads the configured player, does not grant

The builder checks controller/motor identity and actual shared tuning/resource/recoil links, reads the equipped valid weapon, enabled jump capacity, actual hook flag, nominal recoil-compatible primary/positive motion/energy capacity, and obtains conservative world-axis collision half-extents from the actual single enabled rectangle including transform/offset. It refuses unsupported/ambiguous enabled collision shapes instead of substituting defaults. The template's ability list is replaced with these actual nominal tags; the input template and all player services remain untouched. There is no capability grant/configuration call.

Effective tuning/weapon/traversal/resource/equipment values and transient availability are separately captured. It expressly distinguishes nominal enabled capacity from remaining actions, current energy, cooldown or traversal state. Weapon-specific movement not representable by shot_recoil is omitted and disclosed. Conformance profile selection is caller-explicit, not inferred from930001. These nominal tags are generation inputs, not proof of route reachability or a guarantee that the current flight can execute an action.

No additional confirmed defect found in the reviewed final files. New tests/actual runtime outcomes, source entrance commit/cleanup integration, Web export and complete-map mechanisms remain outside this static signature and require their own evidence.
