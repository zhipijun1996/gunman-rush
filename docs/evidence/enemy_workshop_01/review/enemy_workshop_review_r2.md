# ENEMY-WORKSHOP-01 R2 — limited code review

**REVISE: one newly reproduced draft-loss blocker.** R1's three requested changes are implemented; deployment/browser/production storage is still unverified here. Original R1 is not rewritten.

Independent execution: `node --test tests/api.test.mjs ui/tests/core.test.mjs`, **27/27 passed**, exit 0, 150.975 ms. Log `/tmp/enemy_workshop_r2_node.log`. Re-running the R1 API counterexample now refuses the chapter-external recorded-action approval with **400** (previously 201); log `/tmp/enemy_workshop_r2_api_counterexamples.log`.

R1 closures: (1) first uncertain payload is persisted as `last_submission`; exact replay and explicit conflict-only UUID fork exist for review/idea, with `submission_conflict` distinct from `revision_changed`, which cannot fork. (2) visible limits and pre-submit checks match API 3000/5000/100. (3) `isRecordedAction` checks finite ordered intervals with one 60Hz-frame chapter tolerance; build calls `validateCatalog`, covering identities, action/media/source binding and conflicting media aliases. These changes retain immutable rows and do not automatically promote historical footage or whole-monster approval.

**New blocker — late review response overwrites a newer draft after leaving/re-entering its context.** `ui/app.js` `submitReview` captures `draft`; `sendDraftSubmission`'s persist callback unconditionally `remember(key,value)`, and the success `else` also unconditionally persists that captured object. Reproduce: A submit pending → leave A → return A (`loadDraft` reads a new object) → edit A → old A response succeeds. `state.draft !== draft` enters the else and writes old content over the newly persisted edit. The visible textarea still contains the new text, but reload loses it. This is separate from the now-fixed uncertain-response/UUID conflict flow.

Executed **actual `submitReview` function** with a minimal DOM/localStorage adapter and delayed real Fetch Response: `/tmp/enemy_workshop_r2_race.mjs`; log `/tmp/enemy_workshop_r2_race.log`: `currentVisible="NEW USER EDIT AFTER RETURN", persistedComment="original"`. Preserve/merge the latest stored/live draft when the captured draft is no longer its active object, including both asynchronous persist callbacks and success handling. Add this leave-return-edit-before-response regression; the 27 current tests exercise recovery helpers, not this full event sequence. The fix must also retain original uncertain payload and avoid overwriting a context merely because a previous request completes.

Catalogue is explicitly in progress: a direct `validateCatalog(data/catalog.json)` during review correctly rejected `patrol_drone-underworld-52d0a0ada210-a65b2c6efe7a-0` for recorded actions without playable movie URL. This is **not** asserted as a new production-code defect; final build/catalogue/public media must pass after integration. No old build can substitute.

Zoom source uses transform-only scaling/pan on the real video; no time mutation in zoom functions was found. Interactive drag, playback events, focus/mobile layout, all acknowledgement/replay/fork paths, native Sites D1 provisioning/migration, trusted edge auth headers, deployed owner isolation and persistence still require their actual evidence. Parent reports real local Wrangler D1 checks; I have not independently rerun/inspected those receipts in this source review. No G5/art/animation-quality/listening/device/user acceptance signed.

Reviewed SHA snapshot:

- worker/index.js `3abb5cc6c01a67a1859c2a742e2bd260327664ef96f506293f40918bad5a3f35`
- scripts/build.mjs `7897a42d589ee6ff911e7b1decb56d3181b457e2b411cc8f8e513c807887533c`
- ui/app.js `a648a62540e8b4a1a2739f14cbe3b60f65a6d43e158937f720713ac8b08eaeae`
- ui/index.html `580e917d7a3aaa6bca9c062535a19c7688f360e928638a9d586eca0a53258427`
- ui/styles.css `e1e8585438587b04253e30b800f9b32335b242a78eb784a321f1aed5b3fdbd0f`
- tests/api.test.mjs `344be46279a83f15cee7433291aa69c1736dda4ab47e761bd0275bcb00100526`
- ui/tests/core.test.mjs `7dbb3cadd383c6511b97966f3b0cc3daeddc3741be363fe7463706e5c5b1a106`
