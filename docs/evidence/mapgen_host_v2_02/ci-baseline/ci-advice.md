# PR127 batch A: exact failed CI baseline

Run 41510336068 / attempt1 / pull_request / Production impact ran head `9e97b553b7b51cbc64922ed94281061202e3e58b`. Prepare succeeded. Parallel failed; serial succeeded; affected rejected the failed prerequisite. This is not a timeout or gameplay failure.

Actual original reports: full172 expected; parallel executed8 (7 PASS, quality FAIL,84 not executed), serial80 PASS. Total87 passed/1 failed/84 not executed/0 reused. Quality exited1 in4.164s with exactly `FUTURE-FEATURE-ARCHITECTURE-01.json: Evidence hash mismatch: scope`. Serial wall1874.417s; parallel47.664s. Both reports' source/toolchain before/after match, original manifest/argv/budgets and all88 original log hashes verified. Partial lane reports do not approve full172; no merged proof exists.

Original API, four job logs, both small phase-proof ZIPs/reports and isolated quality.log are retained here. No large lane media artifact was downloaded. `ci-facts.json` records counts and the84 unexecuted IDs. API ZIP digests were checked against actual bytes.

## Minimal restoration

`FUTURE-FEATURE-ARCHITECTURE-01` scope binds `docs/architecture_extensions.md` SHA256 `2c3ba48c3df480d643ec5ee19a9f5d9fd300e6862f34f6d7238b8c29e64b2e87`. Both card source `4ed961113a65068e3d488c0370cb573154a2bd14` and main `30e36c9abe223f26e666ceaf796e3fe9cb58e10f` contain exactly those8059 bytes. The card itself is unchanged from main. PR127 inserted a341-byte navigation paragraph, producing8400 bytes/SHA `cea3b7b6474b99df8acd11097de1f81f9418e08885ab33fba7c0a98992f142be`.

Restore only that document to the exact main30e/card-source bytes. Keep the new navigation in `docs/architecture.md` and the new task's integration/upstream documents. Do not update the old quality card's SHA, source_commit, content_version or passing evidence. No new version or historical archive is required to undo this accidental insertion. The exact8059-byte original is also preserved externally as `architecture_extensions-30e36c9a.md` and `architecture_extensions-4ed96111.md`.

Current quality-record scan found no direct evidence SHA binding to `docs/architecture.md`. MAIN-PR96-REPAIR-01, FOREST-FRUIT-ROUTES-04 and MAPGEN-HOST-V2-01 merely list it in affected_paths, which is not an immutable evidence hash. Only the future-feature card directly binds architecture_extensions. Thus keeping the new navigation in architecture.md does not require changing those old cards. This is a finite current quality-record scan, not a claim about all historical documents.

## Exact future verification (not executed here)

After root's authorized fix and commit, record the actual new head; do not label old9e97 results as that new source:

```bash
git rev-parse HEAD
git status --short
sha256sum docs/architecture_extensions.md
GUNMAN_TOOLCHAIN_ROOT=/workspace/toolchains python3 tools/harness.py --check docs --check structure --check quality --jobs 1 --release
python3 tools/production_plan.py --base 30e36c9abe223f26e666ceaf796e3fe9cb58e10f --stage integration --plan --output build/mapgen_host_v2_02/integration-plan.json
```

The restored document must hash to `2c3ba48c...`; local gate commands retain their existing budgets. Confirm the generated plan's source_commit equals that exact new head. The PR Production impact workflow must then pass prepare, both fresh full lanes and affected on the exact new PR head/base. Its same-run merged proof must attest172 unique checks,92+80,0 reused and original logs/source/toolchain identity. Prior9e97 serial80 is retained evidence, not reusable approval for a different head. No additional manual environment run, budget change or retry was performed by this audit.
