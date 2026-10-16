# V3 production loop and short-region routing

Task `V3-PIPELINE-01`, process scope. Extends `tools/production_loop.py` through the original `tools/harness.py --mission` entry. Does not alter gameplay, grant H, open the forest, launch a background model service, or create a second production loop.

## Recoverable phases

Each task persists implementation → checks (one checkpoint per completed check) → independent review → quality. `checkpoint.json` binds the phase, round, results, call directories, invocation bytes, Harness log bytes and source snapshot. The state references its SHA256. Completed tasks retain `completion_checkpoint`: restoration checks both the retained bytes and semantic completion, including successful invocation termination, log success markers, raw CLI events/host response binding, and independence from every implementation agent in the mission. Historical design-stage source hashes may precede later authorized implementation; evidence bytes and identities may not change.

The actual first independent review rejected `V3-PIPE-REVIEW-001`: a revoked lease and matching response arriving in one polling interval bypassed the old loop-body-only check. Round 2 rechecks revocation and both elapsed/absolute expiry before reading the observed response, after parsing, before result publication and after publication before return. If publication races cancellation/expiry, the bytes move to `rejected_result.json` and invocation remains failed/expired, never completed. The original rejected candidate, real review lease and simulated acceptance-consumer reproduction are preserved byte-for-byte in `docs/evidence/region_production_v3/pipeline/round1_candidate/` and `round1_reject/`. Tests separately inject cancellation during polling, parsing, validation and result write, and expiry during parsing/write. These test transports remain explicitly simulated; real kill/resume remains a parent drill.

Clean checkpoints resume with the identical mission, source and worker transport. An active interrupted call remains blocked by default. No invocation is silently replayed and no budget is refunded. The original failed call and lease remain readable.

```sh
python3 tools/harness.py --mission build/mission.json --execute --worker-mode host --evidence-dir build/verification/v3-drill --stop-after-phase checks
python3 tools/harness.py --mission build/mission.json --execute --worker-mode host --evidence-dir build/verification/v3-drill
```

`--stop-after-phase implement|checks` provides a controlled pause before the next worker. For a real process kill during a host review: the active Codex host first interrupts the actual review agent and saves the raw cancellation tool output, then writes `host_cancellation.json` in the interrupted call directory:

```json
{"request_hash":"exact old hash","cancelled":true,"agent_id":"/root/actual_agent","host_evidence":"/absolute/path/to/raw-cancellation.json"}
```

Resume the same original command with `--recover-interrupted`. An unexpired lease requires that cancellation receipt; an expired lease may be revoked directly under the existing host duty to stop its worker. The original request hash is verified, `lease_revoked.json` is written, and the unfinished role receives a fresh directory/nonce (for example `review_retry_1`). The successful implementation and completed checks are reused. The consumed original call remains in `calls` and recovery history. Source changes during an interrupted implementation, legacy calls lacking phase checkpoints, CLI interruption, or malformed/tampered evidence require a new evidence directory and revalidation. A lease file/agent name is local consistency evidence; real host call records remain necessary to establish that the named agent actually ran.

## Package stopping and transport budget

Tasks remain topologically ordered and execute sequentially in one worktree. A normal package-level blocked/awaiting result stops that package; its descendants get `dependency_blocked` and explicit `blocked_by`. Later independent packages continue. Unexpected source writes, malformed results and other integrity exceptions still stop the runner for inspection.

Optional mission policy:

```json
{"transport_retry":{"max_retries":2,"backoff_seconds":1}}
```

Defaults to zero retries. Only classified CLI transport failures/timeouts with unchanged source are retried, with exponential delay capped at 30 seconds and at most two retries. Every invocation consumes the original `max_calls`; retry evidence uses separate directories. HTTP401, token refresh/access-token failures and sign-in failures are authentication failures, even if the message also says stream disconnected. They are never retried. A host lease timeout does not prove its agent stopped and is not treated as a safe automatic CLI retry. Creative/device awaiting decisions are not transport failures.

## One-sentence forest request

`python3 tools/level_design.py route --request "制作荆棘森林" --output build/forest-mission.json` still loads the existing region registry, source-cited regions/weapon authority, latest overrides, legal S2/H entry and scoped lessons. It now creates explicit ecology, Boss, asset-family and animation packages before the combined golden and integration. Ecology/Boss/assets depend on the shared design; a rejected unrelated spatial golden cannot stop those independent packages. Animation depends on its real content/assets. The combined golden and promotion depend on their own prerequisites and existing gates. No package changes basic physics, current-weapon count or formal progression to fit a challenge.

Shared Plains/Foundry checks remain regressions. New-region production tasks additionally carry `region_proof` identity/scope/gate requirements. Their quality records must reference `region_proofs` containing a capture `path` and `sha256`. The capture uses `artifact_kind=region_production_capture`, matching region/proof kind, `scope=actual_region_prototype|actual_region_formal`, nonempty native assertions/observations, actual consumer path, full source commit and observed single-current-weapon/capability snapshot. Its adjacent `.invocation.json` and `.log` must bind an exit-zero actual Godot command, exact capture/log hashes, current source inventory and actual consumer, engine version and `REGION PRODUCTION: N assertions, 0 failures` completion. This is the strict consumer interface for region-specific producers, not automatic implementation of a complete forest. The actual H-only runner described below is a separately scoped prototype. Missing native proof stays unverified; a design JSON, shared Plains PASS, base Foundry PASS or plan cannot grant admission.

The current authority extractor still reports no **formal** forest consumer or formal runtime availability. A separate [H-only prototype](forest_h_slice.md) now has a real native runner; this does not open the forest or grant H in the campaign. Route generation authorizes no formal opening or capability grant. Full forest routes/Boss/animation, independent pixels/continuous footage, player/device acceptance and deployment remain separate tasks under their actual authorization.

The final one-sentence request was actually executed by the existing controller with two distinct real host workers, not just planned: [original requests/responses, native checks and terminal replay](../../evidence/region_production_v3/forest_final_actual_loop/README.md). Terminal state is completed with calls2 and **content_complete=false**. Native H185 assertions/169ticks and two genuine480tick negative runs establish only that technical slice; nine other production packages remain pending. Terminal replay did not create another call or change state bytes. The two actual sparse fixture failures and native exit leaks remain retained. The later directory-input repair has separate [84-test/real-Git independent evidence](../../evidence/region_production_v3/forest_fixture_preflight_independent/README.md), not retroactive approval of those failed invocations.

## Verification scope

Controller tests explicitly simulate workers/processes to test checkpoint recovery, evidence tampering, independent-package continuation, safe retries and authentication failure retention. They are not actual host/model/native execution. Real workers/native checks and terminal replay above are separate evidence; they do not prove every active-call kill/recovery path. Earlier disappeared controllers/orphan states and unconsumed responses remain preserved, never reconstructed as completed. All engine/movie suites must use the parent shared engine lock; this process package only runs Python checks. Sending a message to a completed collaboration agent does not restart it: the active host must issue an actual follow-up task, observe running state and retain the real result.
