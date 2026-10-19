# Frozen historical evidence for parallel integration

These are byte-identical historical files, recovered from the exact Git objects listed below. Their existing evidence SHA-256 values are unchanged. The current editable plan and current global asset manifest have evolved; neither frozen file certifies their replacements or this integration.

TILE-MAP-PLAN-01 retains its original source/review metadata and planning-only scope. Its plan first appears in commit a39a56a85282ba86a642e8263cbbfc28cadc47e1, after the record’s named baseline 4ee004dfda4debc27be07ea1d001fef3b32515b5; that historical attribution limitation is retained, not rewritten as a new review.

The blob47 manifest is a historical generation record from commit 222ee12fa002710de104d31f660ee275c1e6d2f6, not provenance coverage for today’s assets/manifest.json. The rejected visual status remains failed.

```json
[
  {
    "original_commit": "a39a56a85282ba86a642e8263cbbfc28cadc47e1",
    "original_path": "docs/tile_map_production_plan.md",
    "git_blob": "a6267be00e79b2e12555ead8970fe01a67114952",
    "frozen_path": "docs/evidence/parallel_integration_01/frozen/tile_map_production_plan_v1.md.txt",
    "sha256": "9553fcf20bc7175768811e84729da042ac256cd392bad84154452f0b35231780"
  },
  {
    "original_commit": "222ee12fa002710de104d31f660ee275c1e6d2f6",
    "original_path": "assets/manifest.json",
    "git_blob": "0e7ee76ffc9ecc4d2d25af313288d9742040580b",
    "frozen_path": "docs/evidence/parallel_integration_01/frozen/blob47_assets_manifest_v1.json",
    "sha256": "5929927a7d9f0112f01ea0477c85c3d97a98a0f7a362831a17a3fe11f14869e5"
  }
]
```

The frozen Markdown has a `.md.txt` carrier extension so documentation link checks do not reinterpret its original relative links at the archive location. Its bytes and SHA-256 are unchanged.
