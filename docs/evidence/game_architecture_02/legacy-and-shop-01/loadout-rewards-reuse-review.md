# Loadout / item / reward reuse review

Reviewed `/workspace/gunman-rush-migration` at observed HEAD `986bb75d68213879366b824485f482e553158944` while asset migration was in progress. This was read-only static source tracing. No reviewed-tree file was changed and no engine was invoked. No new blocking ownership defect was found in this bounded scope; this is not engine/release approval. The formal teardown leak investigation is separate and unresolved.

## Algorithms already shared

- RewardService, ShopService and home carry acquire through BuildState.add_item and RunInventory.add_item_checked. Repair and item coin awards use the inventory-owned checked patch. No old external inventory snapshots remain.
- RunWallet owns actual coin grants/debits/refunds; SupplyHealEffect delegates to HealthState; MetaProgression owns notes/persistence. Pickup/chest dispatch is not a second copy of those algorithms.
- RunManifest and live BuildState use the same modifier resolution functions.
- Projectile actives and G05 use the same ItemActiveCast preparation/commit. RunSession discards balance through Wallet. No production external wallet balance assignments were found.

## One exact duplicate extracted separately

Candidate `3a8e0efb`, parent `d8144d39`, only changes `scripts/shops/shop_service.gd` in the isolated loadout tree. Both purchase commands now call the existing receipt replay helper used by repair/reroll. All invalid-input/payload prefixes and post-replay validation/payment/receipt/signal suffixes are unchanged. Already-settled replay remains before stale/session/balance checks. Structure reviewer reported bounded static ACCEPT; native execution remains with root.

## Deferred optimizations requiring traces

- `game/loadout/equipment/equipment_service.gd:96`: V5 eligibility checks are followed by repeated required tags/capabilities/weapon checks. Legacy items still need generic validation. Any reduction must preserve refusal precedence and real legacy consumers.
- `game/presentation/ui/item_v5_shop_presenter.gd:243` and `game/loadout/effects/item_defense_effects.gd:218`: additional Build/Runtime refreshes occur after the underlying commit/patch already refreshed. Later refreshes may observe intervening synchronous callbacks. Record signals, revisions and damage authorization before deleting them; no blind removal in this batch.

## Resource dispatch: keep caller protocols separate

| Consumer | Acceptance and receipts | Caller-specific effects |
|---|---|---|
| DemoApp pickup, line 2154 | run/stage/id; reach/readiness; full-health rejection; unknown kind rejects; note save failure does not claim | Always cues accepted pickup; coins_collected, supply used, pickup motion/position/time and player feedback |
| DemoApp chest, line 2585 | run/chest/resource; token/modal/choice; full-health rejection; non-coin/non-heart uses existing note branch | Audio only for a new grant (balance delta/applied healing/non-replayed notes); toast, modal, shortcut and manifest |
| SimpleRoomReward, line 29 | Separate event/source replay; no identical pre-heal full-health guard | Stage-local claimed state and committed signal |
| Forest discovery, line 190 | Healing requires positive amount_applied; story is valid | Reading/route/discovery lifecycle |

The actual grant algorithms are already common. Do not introduce RewardManager or a universal result object solely to remove these short dispatch branches. Preserve receipt construction, accepted/replayed distinction, failed-save claim behavior and cue timing.

## Similar appearance does not mean the same rule

- Shop draws rarity then item, consuming two RNG draws per slot. ItemV5Pool consumes one normalized weighted draw per item. Keep their random contracts.
- Defense uses ready_at/map_uses, distinct receipts and heal/barrier admission; it must not be forced into projectile/G05 cooldown_until submission.
- B16/G10 already share kill-bonus logic; B20 has a different total-map-coins cap.
- Run coins, permanent notes and the different domain receipts must keep their existing authorities.

Known prior failures (broken patch refresh rejection without rollback; paid cast ignoring refused progress patch) remain explicitly outside behavior-preserving extraction.

See the adjacent JSON for full chains and evidence paths. No production change was made for the deferred findings.
