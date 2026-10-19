# WINDCHIME-STYLE-01 independent draft review

Reviewer: `/root/windchime_review`, separate agent from production author; production code read-only. Scope: independent WindchimeLab MAP-00 / MAP-01 sample, uncommitted worktree over a39a56a, provisional browser build `908ccb11f333`, not a frozen publish candidate. Verdict at this checkpoint: **REJECT**, pending fixes and a new frozen-content review.

## Actual observations

Read AGENTS, latest art foundation, gameplay-reviewer skill, general review method, relevant production source and S1 region identity. Viewed the actual 1280×720 browser originals `build/windchime-browser/draft/01-entry.png`, `02-terrace.png`, `03-materials.png`, and independently drove browser catalog, Restart, Pause, Materials under catalog and Home. Actually viewed independent Home output `build/windchime-review/gui-draft/05-home.png`; its existing formal home visuals are outside this sample migration scope. Browser collected no page errors; Godot logs include favicon404 and browser autoplay restriction. Full audio was not listened to. No physical device. No complete campaign or random-map acceptance.

## Findings

- **WC-R1, medium, G2, HUD / font consumer:** bottom Chinese operation and material-map captions contain missing-glyph boxes in actual game pixels, although title glyphs render. Need readable font coverage for every actual status string. Root notified before source correction.
- **WC-R2, high, G1/G3, death → Restart / Materials:** actual first enemy is hurt by a real ShootAbility / PlayerProjectile shot before death (3→2 HP). Actual enemy contact kills player and closes DemoLifetime. Restart reactivates PlayerController, but scope stays inactive; subsequent contact causes no damage, accepted real shots cause no enemy HP loss, and a Materials round trip still reuses inactive scope. Unchanged independent `lifecycle_probe.gd` reports 9 checks / 4 failures; strict runner rejects native exit1. Raw failure retained in `lifecycle-failed.log`; no ObjectDB/script error was emitted. Need a fresh valid monotonic lifetime with bound policy, projectile cancellation and explicit sample-world restart semantics.
- **WC-R3, medium, G2/G3, actual projectile presentation:** WindchimeLab reuses PlayerProjectile drawing `assets/plains_v4/spatial/actors.png`, despite the new sample visually resetting terrain, player and enemies. Mechanics reuse is appropriate, but actual projectile art must consume the new family. This is source-proven; a new isolated drawing override should preserve collision/shot rules and formal consumers.
- **WC-C1, artistic judgment, not user acceptance:** airy sky depth and cream/brass/red silhouette hierarchy visibly exist. Large near-solid dark rectangles have too little readable stone material at game scale. This is a refinable visual concern; it is not a geometric or arbitrary texture-density failure. New user steering subsequently accepts roughly this graphic approach while requesting texture/grain and a different Plains hue. Root will revise scene identity toward S1 grass slopes / bridges / low towers rather than floating sky-city motifs.

## Limits and follow-up

The provisional sample does not fulfill full formal Plains migration, modules, generator or campaign. MAP-02 and future regions are unverified. Root owns production fixes. Review must rerun exact failure probe against fixed source and inspect newly exported actual pixels; old screenshots cannot sign the revised palette or corrected HUD/projectile. User aesthetics and physical device stay unverified.
