# ENEMY-WORKSHOP-01 final source appendix

**Limited ACCEPT**, bound to committed Sites source **7843ec091cecdb15390949f00fa69ce7cab848d0**, tree **4197c431bd023a4576eb51324ee2491b17ff9c9a**. Working tree was clean. R1/R2 failures and R3's qualified review remain unchanged. No Game code or deployment was mutated during this review.

The actual c3a4019ec1bf952d5bb243e47aa26d80490ead17 → 7843ec0 diff contains exactly two files: hosting `d1` becomes the Sites declaration string `"DB"`, and the artifact assertion checks that string. Worker/API/business code does not change in that commit. Relative to R3, worker/index.js, build.mjs, API tests, core UI tests and async UI tests retain their exact reviewed SHA. Current UI presentation uses readable labels, centisecond action boundaries, translated generic gaps/context and a collapsed source block retaining full revision/clip/game/context. Submitted IDs/revision/timestamps remain original values, and the async metadata-only merge, current-draft matching cleanup, explicit fork and revision refusal contracts remain in the final source.

Evidence precision: the R3 complete app file was not retained as a Git ancestor (its SHA was recorded), so this appendix does **not invent a byte-for-byte R3→final app diff proof**. The current final UI was read and its critical submission/persistence paths rechecked. Its API request timeout is 7000 ms; earlier R1/R2 reads used 20000 ms. This timeout is a technical parameter, not display formatting; unknown-result recovery remains present. Timing of that change relative to R3 is not established by the stored R3 SHA alone.

Independent final execution: `node --test tests/api.test.mjs ui/tests/*.test.mjs`, **32/32 passed**, exit 0, **165.160 ms**, `/tmp/enemy_workshop_final_node.log`. Direct strict catalogue validation passed: **25 monsters / 75 variants / 12 media identities**. This is catalogue structural validation, not an independent full download/pixel review of all movies.

Read the existing `.sites-runtime/browser/report.json`: it records 15 passed checks with actual Chromium desktop and 390px mobile viewport, local Wrangler D1 and original MP4 byte/Range forwarding, including inert text, real action/time/revision persistence, delayed ACK with return/edit/reload, explicit new submission, idea/export and separate-context durable reads. These are root-produced local-browser observations, not tests rerun by this reviewer or physical-device evidence. The report explicitly excludes production writes. Parent also reports native Sites deployment succeeded and both tables were provisioned/migrated; this appendix does not independently exercise that platform control plane or a real production user session.

Published URL supplied by root: https://gunman-monster-workshop.zhipijun1996.chatgpt.site . Package receipt binds source7843ec0, archive **87c7e789db035b54dc69968127ae3369b53358db0b67bff5bf26198a2a577937**, built Worker **b0c1f517a93123256be0571e2cb1d0b77369d24efe73fb70f0537e6d0f0c00e5**; both actual local files were rehashed and match. This binds the local submitted candidate, not a new independent production byte retrieval.

Final reviewed source SHA256:

- worker/index.js `3abb5cc6c01a67a1859c2a742e2bd260327664ef96f506293f40918bad5a3f35`
- scripts/build.mjs `7897a42d589ee6ff911e7b1decb56d3181b457e2b411cc8f8e513c807887533c`
- ui/app.js `4dfd7197f836b7554380898cec4e1507749dfce02b88ca46c8cd004eb8e3018b`
- ui/index.html `7e51531472908b141327691c4c575b525699c006cc07a8b3fe18266dfc9832d9`
- ui/styles.css `cd01093efa326d3aa198a71dc39628e89d9aea6720face377d186a9cd3b94d69`
- tests/api.test.mjs `344be46279a83f15cee7433291aa69c1736dda4ab47e761bd0275bcb00100526`
- ui/tests/core.test.mjs `7dbb3cadd383c6511b97966f3b0cc3daeddc3741be363fe7463706e5c5b1a106`
- ui/tests/async-draft.test.mjs `8a250bbe5c0c770f0669d0d30149ffcffd89b75208f3c0173ba720c1e3e09f4e`
- data/catalog.json `eb6a78b4a99ef014789ede3d26fb88cf4005ce3531cee9e82b58ad0f8944c04a`
- .openai/hosting.json `ba65c4cf45f166e21197547522f105e1a54995ee128f108e52ec81ee8216d62c`

Remaining unverified here: real production-user authenticated write/read/export/reload and tenant isolation at the deployed edge, independent production artifact/media retrieval, full normal-speed monster viewing, listening, physical device, art quality, G5 and user acceptance. Limited code ACCEPT must not be expanded to those dimensions.
