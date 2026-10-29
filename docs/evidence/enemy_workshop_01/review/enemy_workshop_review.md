# ENEMY-WORKSHOP-01 independent review — R1

Decision: **REVISE before delivery**. This is a source/API review with independent Node execution, not a deployment, D1-service, browser-interaction, catalogue-pixel, or user acceptance signoff. No Game source was changed and no Godot/Sites deployment/credentials were used.

## Executed evidence

`node --test tests/api.test.mjs ui/tests/core.test.mjs`: **18/18 passed**, exit 0, 152.526 ms, log `/tmp/enemy_workshop_node_review.log`. API tests use Node's actual SQLite engine and generated SQL migration behind a D1-shaped adapter; this proves SQL persistence semantics inside that fixture, **not Cloudflare D1 provisioning, remote persistence, trusted identity injection, or browser behaviour**. Three expected database-error logs belong to the failure-response test.

Independent counterexamples `/tmp/enemy_workshop_counterexamples.mjs` and `.log`, exit 0: initial save 201, edited retry 409, second retry 409, one immutable stored row; an action labelled recorded with interval [20,21] outside chapter [1,12] was accepted for approval with 201.

Snapshot catalogue: 25 monsters, 70 variants, 61 non-pending and 9 pending, 37 historical. Scan found no bad commit/hash/recorded-action bounds in the **snapshot**. Catalogue is still being integrated and this is not final media availability/bytes verification. Current source commit label is 52d0a0ada2103b64b53ecc09d342dc85387111c3; lab/formal context and historical labels must retain their distinct meanings.

## Required changes

1. **Recover an uncertain saved submission after the user edits its draft.** `ui/app.js:327–340` sends the draft UUID and only rotates it after an acknowledged successful response. `worker/index.js:39–45` correctly refuses a changed payload under a saved UUID. If the server saves but the response is lost, editing the preserved draft then clicking the offered retry produces 409 forever. The catch path has no recovery/new-submission control. Same issue exists for ideas (`ui/app.js:343–359`). Preserve the original request snapshot/UUID for exact replay or confirmation and provide a clear way to submit the edited content as a *new* record. Do not silently change UUID on every timeout or assume the old request failed. Add event-level regression coverage for a saved-but-response-lost request, edited draft, retry and recovery; protect both forms.

2. **Align visible form constraints with API.** `ui/index.html` allows comment/details 12000 and title 160; `worker/index.js:57,84` accepts only comment 3000/details 5000/title 100. Input accepted by the form is rejected on submit. Use the actual agreed limits in UI validation and attributes and retain the draft/error on refusal. This currently also makes the maximum JSON byte limit unexpectedly reachable for otherwise valid-looking Chinese input.

3. **Make recorded-action validity an enforced shared contract before publishing the final catalogue.** UI `actionRange/canApprove` refuses absent/non-finite/non-overlapping action intervals; API `worker/index.js:56` only checks status/video presence and therefore accepts an impossible recorded action. `scripts/build.mjs` checks project identity and count 25, not capture integrity. Require finite ordered clip/action bounds, recorded action within its original chapter, commit/hash/immutable-source binding, matching `/media` ID and absence of conflicting media-ID aliases. API approval must reject invalid action ranges as well. The existing snapshot has no such bounds failure; the counterexample demonstrates a missing guard, not a finding that its videos are falsely labelled. Pending/historical material must stay explicit; no source-only update can promote an old video to current.

## Source observations that passed within scope

- All private API routes require an owner ID; queries and export filter `owner_id`, SQL values are bound, public rows omit owner/hash. Client cannot choose ownership. Cross-owner UUID collision fails without returning the other owner's row. This relies on the hosting edge **overwriting/removing spoofable authenticated headers**; that trust boundary still requires deployed verification.
- Immutable UUID retries with identical content return the stored row; conflicting payloads do not overwrite. Read-back after insert prevents a database failure from being presented as success. Structured 503 and UI response confirmation preserve the distinction between draft and cloud record.
- Overall, missing and N/A cannot be approved in normal UI/API paths; suggestions/questions remain possible. No whole-monster admission flag is written. Reviews persist monster/action/clip/revision, capture commit, media hash/URL and optional absolute original-video millisecond. Keep revision immutable with the complete action mapping; action bounds are not separately snapshotted in the row.
- Rendered comments, idea text, account names and catalogue text use textContent/text nodes; no HTML injection sink was found. API literal-script/SQL text round-trips safely. Media sources are server catalogue allowlisted, not query-controlled; browser media URL helper rejects non-HTTP schemes.
- Current variant is preferred even if pending, while older ready films remain explicitly historical. UI has per-monster/action feedback, local drafts, cloud record listing/export, time pinning, and proposed-only ideas. Whole playback, seek, loop, speed, frame step, mobile drawer and focus handling are implemented but their event behaviour has not been tested by the seven pure UI tests.

## Deployment boundary

`.openai/hosting.json` has `d1: {binding:"DB", migrations_dir:"drizzle"}` and the self-contained build copies migration files. This is a **Sites-specific manifest**, not a native Wrangler D1 configuration. Native Wrangler needs its own `d1_databases` binding/database identity; its local schema application proves only the local database. I have not established that this manifest shape automatically provisions a Sites D1 database or applies Drizzle migrations. Obtain the platform's actual provisioning/migration result, then verify deployed authenticated create → reload/read → restart/redeploy persistence, another owner gets no rows, export is isolated, migration failure is not shown as a save, and real MP4 Range playback. Do not guess a database identifier, claim storage from the manifest alone, or treat `/api/session`'s `storage:'cloud'` as a DB health check.

Still unverified: actual Wrangler D1 integration, browser interactive workflows and both viewport layouts, final catalogue/video/public-source hashes, Sites deploy and edge auth binding, production persistence and isolation. No G5/art/animation quality/normal-speed full viewing/listening/physical-device/user approval is signed.

## Reviewed byte snapshot

Files under `/workspace/sites/monster-workshop` (working tree uncommitted at review):

- worker/index.js: `4281b7b299ce005fccff9166f967956eab5f627c66fb7186f16f700a3015393a`
- db/schema.ts: `7440c9f47d6c5ffecf16dc15e81eefefa2f85a693e2a2e32fb021d4f30e1f0d7`
- scripts/build.mjs: `50e4288438bd03034d0575983e2d208a4dfb18daaf4a3c4c2593cd423445dd9f`
- ui/app.js: `cb740acdc469a3a93f71032965d8fe881d943eb3b62b26e07761e9cd944148a1`
- ui/index.html: `db4abb30ff5baca42bcd1538e227ca430dbd79f0531e94682e31281f091ab036`
- ui/styles.css: `fad9d4772b3c1aa9ba883ab76112527835bb38f2d2fdc522f1b0c63ab838ed44`
- tests/api.test.mjs: `801d56afe46bcdd8dcc4a309fa345b45ec8838f6a88b99f8cadaad9d61f560f6`
- ui/tests/core.test.mjs: `723d9117b1aecbfcbaae4df23fc2b9597914bca44a777a4d4af15332ebd2e51f`
- data/catalog.json: `9c91aebaada06db352ad8a51bd7e122a318a0d3f5e679b668369e68720484f0c`
- .openai/hosting.json: `daa789ed51d3f3ddb2296f723e5a1a9f461db870f5eead41ffaabc6349760f6a`
