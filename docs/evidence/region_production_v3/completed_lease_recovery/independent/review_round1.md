# V3-COMPLETED-LEASE-RECOVERY-01 independent review — R1

Reviewer `/root/v3_independent_engineering`, read-only. **REJECT** collector SHA `fc8942a352d1cbfd8c729e0d59a3753c8f491b5afe7769daa0f9945cf2cd74aa`: its guarded publication stops before finalization, leaving a reachable late lease/source/evidence race.

Actual `independent_probe.py` used real temporary Git repositories and registered worktrees, actual completed Python subprocess PIDs, original collector function and existing scope quality implementation. Host payloads are explicitly SIMULATED fixtures, not actual Codex agents/native runs. No real enemy request/state/source was modified.

Both baseline cases behaved correctly: valid scope ACCEPT completed with calls2/contentfalse; valid REJECT preserved reject and ended budget_exhausted/calls2. Four real-file/clock changes injected immediately after actual scope quality returned — expiry, written lease_revoked, modified temporary source, rewritten temporary response — each still returned complete, changed original state bytes and left published completed invocation/result. A fifth revocation during quality checkpoint save threw at later invocation verification, but old state was already modified and published result/invocation remained.

Location: `tools/production_loop.py::collect_completed_review`, last `guard()` preceding `record[roles][review]`, `_checkpoint` and `_run_locked`. Its exception cleanup covers only earlier metadata publication; it does not cover checkpoint/finalization writes. Expected: retain lease/source/evidence protections through terminal publication, restore original collector-owned state/checkpoint bytes on guard failure and archive rejected publication bytes. Do not undo unrelated external source changes.

Raw actual outputs and reproducible script: `independent_probe_results.json` and `independent_probe.py`. All original positive/negative assertions remain; no production edits or engine executions were performed. Engineering author was immediately notified and is repairing within this independent tool scope. Original enemy content rejection remains unchanged.
