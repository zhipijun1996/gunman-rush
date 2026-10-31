# ENEMY-WORKSHOP-01 R3 — limited code ACCEPT

**ACCEPT for the reviewed source/API/draft contract only.** R1's three findings and R2's late-response draft-loss finding are closed in this byte snapshot. This is not site delivery, native Sites D1 provisioning, browser GUI, final catalogue/media, production identity/persistence, G5, or art/user acceptance.

Independent execution:

- `node --test tests/api.test.mjs ui/tests/*.test.mjs`: **32/32 passed**, exit 0, 179.087 ms. Log `/tmp/enemy_workshop_r3_node.log`.
- Re-ran the unchanged independent R2 reproducer `/tmp/enemy_workshop_r2_race.mjs`: visible and persisted comments both `NEW USER EDIT AFTER RETURN`. Log `/tmp/enemy_workshop_r3_race.log`. The previous result persisted `original` and remains preserved in R2 evidence.

Source review confirms asynchronous persistence re-reads the latest keyed draft, requires matching UUID and compatible first-request snapshot, and merges only submission receipt metadata. It no longer writes a captured old body. Success clears only when latest stored and current visible draft match the acknowledged payload. A replacement UUID is ignored by the old response; edits remain drafts with explicit conflict recovery. Existing exact replay, conflict-only new UUID, revision-change refusal, matching limits, recorded-action checks and build validation remain intact.

The five added async tests import the **actual submitReview/submitIdea** functions with a minimal DOM/storage adapter and delayed Fetch Response/rejection. They cover review leave→return→new object→edit with success/failure, idea restored-object edits with success/failure, and old successful response against replacement UUID. They are meaningful event-function regression tests, **not a substitute for actual browser integration**. Parent's local Wrangler D1 evidence is separate and was not independently rerun here.

The catalogue is still receiving media URLs, so no in-progress null entry is being classified as a new source defect. Final build must run strict validation after its freeze, then root must verify actual deployed playback/Range, source and media hashes, authenticated identity injection, schema migration, owner isolation, confirmed save/read/reload/export and persistence. Those scopes remain unverified by this code ACCEPT.

Byte binding under `/workspace/sites/monster-workshop`:

- worker/index.js `3abb5cc6c01a67a1859c2a742e2bd260327664ef96f506293f40918bad5a3f35` (same as R2)
- scripts/build.mjs `7897a42d589ee6ff911e7b1decb56d3181b457e2b411cc8f8e513c807887533c` (same as R2)
- ui/app.js `24b7d737292ab9d8ad817190eea05de28ec19443726aac9ba4707a0fcf535710`
- ui/index.html `580e917d7a3aaa6bca9c062535a19c7688f360e928638a9d586eca0a53258427`
- ui/styles.css `e1e8585438587b04253e30b800f9b32335b242a78eb784a321f1aed5b3fdbd0f`
- tests/api.test.mjs `344be46279a83f15cee7433291aa69c1736dda4ab47e761bd0275bcb00100526`
- ui/tests/core.test.mjs `7dbb3cadd383c6511b97966f3b0cc3daeddc3741be363fe7463706e5c5b1a106`
- ui/tests/async-draft.test.mjs `8a250bbe5c0c770f0669d0d30149ffcffd89b75208f3c0173ba720c1e3e09f4e`

No shared source, Game source, credentials, Godot, or deployment was accessed for mutation. R1/R2 reports remain unchanged.
