# MAPGEN-GODOT-03 generated entrance / base hooks / Provider supplement

**ACCEPT for the final source/static scope below. Runtime remains UNVERIFIED by this reviewer.** Read-only non-author review in `/tmp/gunman-rush-mapgen-03`; no Godot/browser/test execution or production writes. This supplements `/tmp/mapgen-v3-independent-review.md`, retaining its original SHA scope and resolved opaque-ticket finding. No full-map, physical reachability, mobile or performance acceptance.

Frozen source hashes:

| File | SHA256 |
|---|---|
| experiments/generation/runtime_map_generated_slice.gd | 419c397524ae57d87e9ded183db510b3f819f79f7772d054753ee7e858d3fce8 |
| experiments/generation/runtime_map_generated_slice.tscn | 5abd26828f1ba704d11ecd757a9eba247abe4417e380e01037fb942f4a48ab37 |
| experiments/generation/runtime_map_slice.gd | 8ed26f637daaa7f46d4a5712e87f3a07ee04ef9bb8348c1cbd0a3f0a1ce735e0 |
| experiments/generation/runtime_map_frozen_source.gd | c1f8e4d6d167c74734a02a7156528fa48460760ec64a9d13b8331509bc5701da |
| game/world/levels/providers/runtime_map_v2_provider.gd | 01c7a8cc58464d45300797bce1a9212eb8dd6f8fa456b87f56927632f032f22b |

## Generation source and profile boundaries

GeneratedSlice overrides `_start_source` and `_load_source`; the generated path does not call FrozenSource.read_inputs/load_level or open frozen map/content files. `read_bindings` reads only the existing host input-lock and bindings bytes. Fixed selected IDs and host spawn bindings are intentional host selection data, not substitute geometry. Generated `_load_source` explicitly rejects reload and requires a fresh job; there is no fallback to a frozen map after generation/admission failure.

Algorithm request/config files are checked against candidate-lock hashes and parsed by the original typed DataJSON. The export-enum profile is explicit: conformance930001 uses original official algorithm request values; controller uses the request builder's actual live-player projection. The actual capability snapshot is collected in either case, and host capabilities separately identify the profile and actual hook/weapon/shape/ability values. Conformance's grapple tag is not applied to the player. Base RunComposition.configure_capabilities(controller,true,false) enables the original energy policy and does not grant grapple; no generated-source grant call exists. A conformance graph is not certified traversable by the actual no-grapple player.

## Frame scheduling, assembly and commit

The generated source owns one envelope/opaque handle, using the inherited actual RunSession lifetime. It disables controller activity while loading. `_process` performs one synchronous generation.tick per rendered frame, returns while not ready, and does not spin the whole solver in a loading loop. Phase/progress UI is local presentation. Preload/admission/assembly remain synchronous and may take a long frame; cooperative operation budgeting is not a frame-time guarantee.

Only the ready branch takes the current plan through take_plan(handle,current_lifetime), then calls the shared base `_install_plan`. Stage, real player presentation/input and one FrameDamagePolicy use the inherited session/controller/lifetime/services. `_approve_install` delegates to the envelope's one-time commit after assembly and manifest acceptance; only success sets ready_ok and reactivates the player. Subsequent process calls return on ready_ok. Failure leaves readiness false, reports failure, stops further processing and retains the cancel/exit route. No solver-owned wallet, policy, RunDirector or second collision assembly was introduced.

The base class hooks preserve frozen loading through its existing default source. Generated reload deliberately returns a diagnostic rather than silently selecting frozen data. Normal source close and `_exit_tree` invoke `_close_source`; the generated override closes/cancels the envelope. Base close then clears input/projectiles, invalidates lifetime, detaches/queues Stage and drains the original world audio. During-loading ESC and the Cancel button share request_exit; hosted scenes use the existing bootstrap's awaited cleanup, standalone scenes close before quit. Static ordering is correct; actual node/audio release and cancellation latency need runtime evidence.

## Concrete malformed-input findings resolved

During review, the initial generated entrance only checked that the candidate lock was a Dictionary, then dereferenced conformance.request/config. A missing nested member could fail before the failure UI. The initial binding-only reader also omitted the original input-lock schema guard. Both were reported to root. Final GeneratedSlice419c3975 checks the nested objects, member path/SHA types and file existence before use; final FrozenSourcec1f8e4d6 requires the original lock schema. These specific rejection gaps are resolved in the frozen sources above. No production edit was made by the reviewer.

## Provider StringName boundary re-review

The upstream real-result StringName-key failure is not reclassified as passing here; the author/root retain that execution failure. Author froze the final Provider01c7a8cc for this review. Generated-source `_data_only` now accepts only finite plain data with textual String/StringName keys, rejecting duplicate normalized textual keys. The new `_copy_memory_keys` recursively creates fresh map/store Dictionaries and Arrays, converts keys only via str(key), preserves array order and returns each scalar Variant unchanged. It does not serialize/reparse data, narrow numbers, rewrite original fingerprint/map_id or mutate original result objects. The original result remains the identity/receipt input. Converted map/store enter the single shared `_build_level` converter.

Independently compared all17 pre-existing helper bodies against HEADe7d703f4: byte-exact, including `_load_identity`, `_digest`, geometry/port conversion and validation. Thus this repair does not relax frozen-source String-only geometry admission or alter its identity function. Generated identity remains explicitly memory data, without fake files/map-byte attestations.

Author reported real admission after the key repair, with three newly added canonical-string comparisons still under diagnosis. This reviewer does not sign that run or its eventual test outcome. Original DataJSON canonical sorts Variant keys; mixed String/StringName key sorting and pure String sorting need not yield identical strings even when normalized text keys and scalar values match. Recommended meaningful new comparison is recursive textual-key mapping with exact scalar typeof/value and original Array order, while retaining original-result before/after fingerprint/map_id/non-mutation assertions. No failing test was removed or signed off by this reviewer.

No unresolved confirmed source defect found within the frozen static scope. Final native/Web/CI outcomes, actual cancel/exit release and complete generated-map mechanisms remain separately unverified.
