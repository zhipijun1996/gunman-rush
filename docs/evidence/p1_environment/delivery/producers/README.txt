Build-only local environment candidate producer. Archive source is restored to its original build path; do not run this archived copy in place, since its ROOT is relative to that original location.

Restore:
  mkdir -p build/plains_environment
  cp docs/evidence/p1_environment/delivery/producers/prepare_local_review_bundle.py build/plains_environment/prepare_local_review_bundle.py

Read-only plan (no Godot, no output directory/source copy):
  python3 build/plains_environment/prepare_local_review_bundle.py

Only after the exact source commit has been imported and strictly captured:
  python3 build/plains_environment/prepare_local_review_bundle.py --execute --expected-commit <exact-frozen-HEAD> --expected-capture <exact-current-strict-visual_capture.json> --output-dir build/plains_environment/local_review_01

Use a NEW output directory. The capture must bind this HEAD and identical current runtime bytes. Keep the recorded capture and source commit when restoring. baseline_asset_paths.json is a conservative path seed derived from the existing prior PCK directory, not its bytes, not a claim of minimum closure. The original PCK is not needed. Every packed byte is read from current source/current .import backend files, with all entries hashed. A restored clone needs the normal Godot import and cached derivatives before execution. No historical 315MiB asset source staging is copied.

This is a local manual review candidate, including failed/unverified art, never a formal release or user/device/art acceptance. Package errors block ZIP delivery.
