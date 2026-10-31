# PLAINS-MOTION-LOOT-02 · loot/App/guard/asset review

**Limited ACCEPT**, reviewer `/root/plains_motion_round2`. I did not edit the reviewed production/tests/metadata or execute Godot. I authored the separate body-motion changes and motion helper; those are explicitly excluded from this review. Current source is dirty development based on2ac54f9f; exact reviewed SHA values are in the paired JSON, not a fabricated clean/final-source approval.

## Actual issues found and repaired

1. Stage-local pickup positions were compared with world player coordinates. Root replaced both proximity paths with `_pickup_within_reach`, uses actual world pickup position, and passes a shallow world-space pickup copy to magnet so its physical LOS remains global. The actual translated App fixture refuses a false local near match, accepts the actual world position and rejects replay.
2. Initial ballistics only queried downward and returned immediately for settled items. Root added real side/roof leading-edge sweeps and support-contact revalidation. Actual native loot123/0 includes translated floor, roof/wall, safe-void return and floor-loss cases without claiming/repricing the entitlement. This is bounded evidence, not exhaustive rotating/concave geometry or platform carrying.
3. `set_pixel_style` replaced restored dynamic life-orb art with the old heart. Root now preserves the orb and updates coin siblings. This code fix is read, but a separate style-switch visual clip is not signed.
4. The migrated old drop test retained17 labels and original frame budgets but replaced automatic collection with per-unit manual calls. Labels alone could not preserve automatic coverage. The separate new actual App counterpart now runs real early proximity ticks, ready proximity→queue→commit, full configured sum and replay rejection. I read its actual native05 results: App44/0, while the migrated old wrapper is30/0 clean. Acceptance is for this mandatory combination; the old runner alone is not an automatic-scan proof.

## Reward and persistence behavior

`settle` retains the old per-enemy RNG namespace/version and one draw. Guaranteed configured coins are explicit; original note/heart draw intervals and existing map bonus caps remain. `rewards_of` is consumed before1/5 splitting. Each unit retains its value/source/ID; App transaction guards own money/HP/permanent-note changes, and rendering cannot claim. The item bonus is applied to the effective coin entitlement before splitting, with configured base recorded separately. Connected-region per-enemy drop records and per-unit claimed receipts prevent repeated death scans, reload repayment or healing replay. Saved ballistics retain actual position/velocity/age/bounces rather than rerolling.

Root's actual native05 is342/0 with no strict parser/shader/ObjectDB/resource error lines; I independently read the loot123 and App44 checked ledgers, including automatic and translated cases. Aggregate body-motion and audio scopes are observed only, not independently approved here. Root still owns final all-source execution and movie capture.

## Asset/provenance audit

Independently executed60 read-only checks,0 failures. Original299 entries and197,774-byte raw prefix plus every other top-level field remain exact; eleven payload additions produce310, represented by ten existing-schema asset records. All ten pass `quality.validate_asset`, all eleven payload hashes match. The nine recorded audio sources, original source page and complete CC0 text hashes match retained records. Generated orb original/runtime PNG bytes are equal, while license/model remain unknown and commercial certification is expressly absent; no CC0 claim is invented. These are byte/metadata approvals, not listening, visual or user approval.

## Boundaries

Keep both old registered drop consumer and the new actual automatic counterpart mandatory for this workline. Do not reassign the development native run to a later frozen head, and do not promote these finite geometry fixtures or asset hashes to normal-speed art/audio, device or user G5. Exact source and artifact hashes, checks and remaining limits are in `plains_motion_loot_02_code_guard_review.json`.
