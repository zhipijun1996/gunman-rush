# MAPGEN-HOST-V2-02 B/D independent static review

Verdict: **ACCEPT for the frozen static B/D scope only; no blocker found.** Native/Web/CI execution is not independently signed. Reviewed WIP over `2e0c497cb45e9889495a59ea54b8c93b30014a0b`; exact six file hashes are in `bd-review.json`. Reviewer is not an author of B/D. No production writes or engine/browser/test execution.

## Permissions

The locked reference runtime-map schema defines exactly INPUT/OUTPUT/INOUT (reference schema lines410–415). Provider line7 and lines153–157 enforce this enum/type; IN, OUT, lowercase, empty and numeric values produce an invalid-protocol diagnostic. `_connection_error` line290 separately refuses legal INPUT/OUTPUT at selected open seams as unsupported host capability. Bidirectional INOUT behavior remains admitted. Tests lines76–90 cover all eight categories without treating legal one-way values as protocol errors. This is deliberately limited seam support, not implementation of one-way seam traversal.

## Identity and trust boundary

Provider lines23–33 validate upstream generation fingerprint, implementation/algorithm, module-package identity, map/library attestation consistency, protocol, binding schema/version and actual active spawn. Lines49–57 compare the actual selected IDs against the binding selection. Lines65–75 require each selected content ref and its attestation.

`_load_identity` lines116–130 hashes the actual complete map Dictionary, each actual loaded content Dictionary, and the complete actual bindings Dictionary with sorted-key/full-precision JSON (`JSON.stringify(value,"",true,true)`). Thus keeping old supplied SHA strings does not preserve restore identity after parsed content changes. Content rows name stable instance IDs, refs, content versions and byte attestations. Generator Dictionary, its source commit and module-package Dictionary are included. The scope is expressly `loaded_instance_refs_only`; unselected content bodies are not claimed to be frozen.

The upstream `request_fingerprint` is preserved verbatim as `generation_input_fingerprint`. Separate `map_content_identity` and `host_load_identity` prevent replacing that upstream meaning. The latter includes adapter version, map-content identity, canonical selected IDs, selection byte attestation, bindings schema/version/bytes/actual contents, active binding, actual spawn, region/index and actual capability Dictionary. Binding-only changes leave map-content identity unchanged. Changed geometry/implementation/library/source or selection changes the load identity conservatively.

Provider remains an in-memory admission boundary, **not an independent byte authenticator**. It trusts caller SHA attestations; FrozenSource lines7–25 separately verifies the fixed six on-disk members and library identity, then passes verified values and actual bindings (line38). A co-versioned lock is not a cryptographic signature. This explicit boundary is retained, not hidden by the new digest.

## Restore, records and invariants

Slice line81 records the detailed detached identity alongside `plan.map_hash`. Reload lines102–110 captures old state, admits current inputs, and compares saved identity against the **new** plan hash. The mismatch returns before input/projectile clearing, epoch invalidation, old Stage removal, state replacement or node assembly (lines113–129). Capturing the current clock snapshot occurs before the guard; no replacement content is installed. Existing Stage lines13–15 also refuses mismatched state before `LevelRuntime.assemble`.

Existing PlainsRegionState version1/2 restore guard (lines23–24) remains unchanged and rejects old weak hashes. No state/permanent-save schema or shared Plan/Runtime/Player implementation changed. FrozenSource only adds the new Provider inputs. Bindings gains schema/version; its actual SHA matches the updated input lock.

## Tests and evidence limits

All **32 original complete `check(...)` assertion-line occurrences** from9e97 remain byte-exact after indentation trimming (Counter inclusion; static evidence only). New tests lines92–145 cover content changes with stale byte attestations, non-active binding content, binding version, selected set, implementation, library and generator source; generation fingerprint preservation, old state refusal, real Stage rejection before creating geometry, reordered selected IDs and prior weak record rejection. The actual reload rejection order is established by source inspection; added tests use Provider/state/Stage for mismatch cases rather than mutating res files during real reload.

Read root's `/tmp/mapgen-v202-identity-01.log`: marker194 assertions/0 failures, three released-audio teardown records, no error lines. This reviewer did not run it or independently attest its process exit/source binding. Later native/Web/CI facts must be attached with their own frozen source and exit receipts.

Nonblocking strengthening: add a valid numeric mutation below default JSON decimal precision with unchanged supplied SHA, plus a Dictionary key-order-only permutation. The required full-precision/sorted flags are present; these cases would directly guard against future flag regressions.
