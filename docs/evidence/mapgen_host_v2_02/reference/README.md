# PR127 user C: verified Python-reference development tooling

The minimal reviewable tool is `candidate/verify_mapgen_reference.py`; `candidate/run_negative_checks.py` exercises meaningful rejection paths only in external copies. Nothing was added to the game repository. Python/the full ZIP remain outside game resources and exports. The tool does not implement generation, a new map protocol, actor registry, runtime Python bridge, or a Godot algorithm.

## Exact upstream and artifact

- PR2 head:0d338c2309d4e17bd8e9b128f745eb93938e99b2.
- Locked GitHub path:reference_package/releases/0.2.0/mapgen-python-reference-0.2.0.zip.
- URL:https://raw.githubusercontent.com/zhipijun1996/map-gen/0d338c2309d4e17bd8e9b128f745eb93938e99b2/reference_package/releases/0.2.0/mapgen-python-reference-0.2.0.zip.
- Actual ZIP:1869684 bytes, SHA25625f05861b68a99eee1e9d588eb2cab761e30c85b7cc109b0536292fcc98867f6. The exact-head upstream sidecar was fetched and matches.
- Actual source recorded inside manifest:1b20031c60ee0269d03c1e89eb52f0a0f0fc70bf; original algorithm baseline178c40164c2f7371ce1c8a56cde658e84a4f42c2. These are distinct from the final PR head, per the original handoff.
- map-edit1.1.0 dependency SHA2565ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723; no module upgrade.
- `fetch-receipt.json`, ZIP/sidecar API metadata, `upstream-tree.json`, `zip-member-inventory.json` retain exact URL/status/Git blob/full SHA/member list. Original AGENTS/handoff/release-validator source leaves and their API metadata are under `upstream-leaves/`.

Readiness remains python-reference/reference-only, Godot/Web/desktop algorithm NOT_IMPLEMENTED. Existing host support for frozen data is separate evidence.

## Reused protocol and actual execution

Safe extraction duplicates the exact one-root/duplicate/absolute/traversal/backslash/symlink rules from the same upstream head's `tests/reference/validate_release.py`. The tool then invokes the shipped `reference.py` verbatim with `-B -I -S`, unrelated cwd and an explicit bundled locked module ZIP. No custom replacement validator/schema was written. Logs and receipts stay outside the extracted package, preserving its strict file inventory.

Executed command:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 candidate/verify_mapgen_reference.py \
  --archive mapgen-python-reference-0.2.0.zip \
  --host-data /workspace/gunman-rush-refactor/resources/levels/mapgen_host_v2_01 \
  --out /workspace/refactor-evidence/mapgen-host-v2-02/reference/verification-01
```

Actual shipped verify exit0(0.348s), shipped replay-all exit0(4.536s). Both success and failure samples were checked. Failure remains SEARCH_EXHAUSTED with map=null/store empty; successful verification of its refusal contract does not turn that generation result into PASS. `verification-01/receipt.json` contains exact argv/cwd/exits, unchanged upstream receipts, all manifest file/source hashes and input hashes. Individual stdout/stderr logs are preserved. This is not a rerun of upstream's entire11-check release validator/deterministic ZIP rebuild or Godot suite.

Success inputs are the original930001 request:jump/double_jump/shot_recoil/grapple,clearance[12,18],all regions/modules,original start/boss bindings. Stable-v2 goals remain32 growth/6 rewards/3 main paths. Full request/config/lock/provenance reside in the verified sample, with actual file-byte SHA recorded in the tool receipt. No goal, seed, filter or content was changed.

Byte comparison passed4/4 against current main-repository resources:

| File | Bytes | Exact SHA256 |
|---|---:|---|
| map.json |547741|2c47b81e754e3500df1c5e9723b19b1bc99fcd20751d8ae05fd2af55a3ebc6c0|
| content/M16.json |1425|9cfa577517940be7e715942d32b0afebe39226faf6a0d8c51aa40885eb87d496|
| content/M18.json |1040|e1e0a2f82917adad1c69a723d2276a44e112feab6719d8ea4c3b96b86e5e7512|
| content/M21.json |1040|e1e0a2f82917adad1c69a723d2276a44e112feab6719d8ea4c3b96b86e5e7512|

The tool never writes a host resource and refuses output inside that resource directory. Existing evidence/output directories are never overwritten. New attempts must use new directories; errors retain their receipt/logs where output was created.

## Meaningful rejection checks

Executed3 checks via `candidate/run_negative_checks.py`, result/logs in `negative-01/`:

1. Append bytes to a copy of the reference ZIP:locked outer hash rejected before extraction/output creation.
2. Change only copied host M16 ellipse_x_sign from-1 to+1:original package verify/replay still pass, exact comparison rejects that one file, no original host write.
3. Change the extracted package's copied M16 content direction and recompute the inventory/source hash fields using the original release-test resign helper:the original verifier still rejects `unresolved or changed content_ref:content/M16.json` against its complete frozen result. This tests semantic reference binding beyond a stale manifest checksum.

Additional recommended original upstream cases (not newly executed here):missing content after rehash;failure result carrying map data after updating provenance;false Web readiness;RNG vector order changed after rehash;wrong locked dependency ZIP. They already have concrete mutation/expectation patterns in the frozen upstream release validator. Preserve underlying failure state and do not loosen checks/budgets. No current production source was changed to make negative checks pass.

## Next real mechanism recommendations, outside this batch

Exact instances/versions/content SHA/counts are in `next-mechanisms.json` and refer to the verified locked sample.

1. M35/game-plains-ferry-gears:4 platforms,1 static hazard,1 oscillating saw and2 linear ferries;no enemy/reward/latch/HQ payload. This is the smallest next real hazard/trajectory module target. Its source contentVersion is sha256:18e0578b0631239884f0ff9bb598b04867396bcbe3988c036b512ebe32e092b3. Do not omit its hazard/saw or call an isolated module a complete neighboring slice; actual adjacent content remains separately scoped.
2. M01/game-plains-windchime-lesson:2 platforms and1 real safe_lesson bell/gate. Useful for a later native projectile→bell→gate test. Its original spawn/entry sealing caveat remains; this tool does not invent a spawn or qualify that interaction.

No new mechanism, enemy, reward, Boss, runtime generation or gameplay integration was implemented here. Package/static/reference success does not certify host movement, arbitrary seams, mirrors/seals, whole-map physics, Web runtime generation or device performance.
