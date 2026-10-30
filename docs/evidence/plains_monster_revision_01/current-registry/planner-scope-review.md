# Planner inventory scope migration · independent review

**Verdict: ACCEPT, limited to `tests/test_production_plan.py`'s inventory/routing guard migration.** Independent reviewer `/root/planner_scope_review`; no repository edits, production changes or Godot execution. Exact reviewed test commit **a72a313a3fabde570733265aa7e2d795d70768c3**.

Actual test SHA256: `71c9f51b13332659119ea16765776df2722bdabcfadc94ea943f85dc4d48109a`.
Actual profiles SHA256: `7e4309aaf8d6a5d30f05951db5035ed3e8f2fdb8bbcbae8413cc5d02379a05f9`.

## Why the old test failed and authorized scope

The full04 original check really failed after29 passing checks: the physical inventory test still expected the frozen historical registry ID in the default full inventory. AGENTS.md's existing current-Demo/compatibility deferral explicitly retains frozen historical replay in manual `legacy-compat`; this does not waive current saving/gameplay. Previous independent current-registry review covers the substantive replacement, not this later test migration.

I independently reconstructed both old b479 inventory and actual production planner output: the original legacy item was at full manifest index74 and sorted plan index85. The new current item occupies those exact positions. The replacement's old check dictionary/argv/budget is byte-equivalent as a JSON value; current and original outer budgets remain210. No frozen fixture or old native replay assertion was changed in this revision.

## Strictness preserved

All four existing historical SHA256 constants are unchanged. All existing lane-disjointness, union, inventory order, addition prefix/order, full166 and lane91/75, serial metadata and scoped-command assertions remain.

The added guard requires exactly one current ID at literal index74/full manifest and85/planner, forbids the old ID in both default inventories, retains old ID in legacy-compat, forbids current ID in legacy-compat and requires current/original timeout equality. Only for the four historical hash comparisons, the exact current ID is mapped back to its original historical ID. No other name/order/content is normalized. This does not merely replace an expected digest with today's digest, and an unnoticed restoration of old default coverage cannot slip through the normalization because the explicit current/old membership assertions run first.

The `original` baseline variable still contains the actual current names for added-lane comparisons; no obsolete legacy name is used to misclassify the current check as a new append-only family.

## Executed checks

I independently ran the complete existing Python suite: **21tests/0failures**, actual0.096seconds; `/tmp/plains-planner-review-suite.log`. I also executed the exact inventory test against actual data plus18 independently mutated in-memory profiles/plans: **19checks/0failures, all18 corruptions refused**. No actual file was modified by the mutations.

Negatives covered restoring old default ID, duplicate/appended/moved current ID, dropping/reordering/duplicating unrelated historical inventory, removing legacy entry or placing current there, changing current budget, changing its serial lane, reordering additions, removing structure-native, shifting only planner current slot, reordering planner historical/addition entries, lane overlap and lane omission. Script/result: `/tmp/plains_planner_scope_mutations.py` and `/tmp/plains_planner_scope_mutations.json`.

## Limits

This accepts only the concrete test migration and its executed pure regressions. It does not turn the full04 failure into success, sign an unexecuted final163/full166, replace final native current-registry execution, accept old frozen replay failures, certify pixel art/animation/audio, or sign user/device acceptance. The reviewed test bytes are exact a72a; surrounding receipt/docs changes were outside this review.
