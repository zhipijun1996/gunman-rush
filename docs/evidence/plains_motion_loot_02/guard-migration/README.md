# Physical denomination consumer migration

The exact original `tests/plains_cohesion_drops_runner.gd` from merge2ac54f9f is preserved as `plains_cohesion_drops.before.gd.txt`. The actual old native result was17 assertions/4 failures (`old-drop-17-4.log`), with old test bytes against the current dirty development production; it is not a clean2ac54 run.

The user explicitly requires each monster to guarantee its configured coin total, physically split into1/5 denominations, then spray/bounce and collect individually. The old token's final authoritative position was static while its Sprite flew cosmetically. The new item's actual position now moves, and each denomination owns a separate receipt. Thus `sprite.position != pickup.position` and `wallet_delta == first_unit.amount` are obsolete consumer assumptions.

The migrated consumer keeps every one of the original17 assertion labels and the exact ordered frame waits (2,8,2,42,18,8,48,60,3), plus the two paused process-frame waits and strict original audio teardown. It observes the real flight during the same42-frame interval from the existing safe spawn, commits each ready coin at its real location through `DemoApp._commit_pickup`, rejects every repeated receipt, and compares aggregate wallet and restored units to the separately recorded configured total. It retains visible absorption/disappearance, pause/reload/no-replay/no-repayment and the original Boss seal/environment-return assertions. Extra bonus note/heart entitlements are not forced or bypassed by this coin-scoped test.

This author did not edit production or old runner budgets, did not run Godot, and does not sign an independent review or fresh PASS. See `migration-proof.json`; root must execute the registered original check and obtain a different reviewer.
