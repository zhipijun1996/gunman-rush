# Independent capture-adapter correction review

Reviewer `regional_review`, no production/test edits and no Godot execution. This addendum preserves earlier independent-tooling/native reports unchanged. Source reviewed after original full01 failed adapter admission, before subsequent frozen capture/pack execution:

- `tools/visual_director.py`: `542acfac931ab5c84c70a290aabe318879215c6ffd9b46f8296bb27f21333f47`
- `tests/plains_regional_art_capture_test.py`: `42e7dbcd59868e7ca6e0b29f697d0f45979558a52c7a3aaa34694de4fe092fda`
- `tools/prepare_plains_regional_review.py`: `f10d74c4b33b2a6c2742834f13612d98aec7685509839bb8a025d31ededee1a2`

## Failure and changed responsibility

The new regional runtime does not emit the old optional visual-sample/layout treatment fields. Original capture validator still required them solely because empty flags were present in the request. The source change scopes that legacy metadata assertion away **only** for the explicitly whitelisted regional adapter. Legacy sample/layout consumers and their original validation remain untouched. Unsupported nonempty sample/layout flags for regional entry are now explicitly rejected rather than silently ignored.

The replacement regional binding checks exact real catalog path and SHA against original source inventory, recursively checks actual painted source hashes, and requires actual selected girl/calibration/texture hashes with one painted owner and unchanged gameplay. This replaces inapplicable metadata with actual consumer identity; it does not waive original route/health/input/source-before-after/engine-error/leak/exit or art omission checks. The actual girl-only capture scope must not be generalized to all selectable avatar states.

The `finalize_existing` path continues to require an originally FAILED visual receipt with an actually successful native producer (exit0); original source-bound native data/log and real retained AVI; no native re-execution. It reruns current admission against original request/source evidence, archives the new adapter file, and makes a NEW adaptation receipt preserving original failure and errors. Increased encode/extract deadline is regional-only, not relaxed video dimensions/rate/audio or frame count. Original failed receipt must remain FAILED and movies retain their actual old runtime source e450, not later tool commit. This review has not independently validated final recovered movie bytes/playback.

The package adapter now derives manual/smoke Seed from its exact expected capture request, restricted to preregistered regional-art-01..06. This avoids comparing Seed01 package data with a Seed02 expected capture. Base producer strict source/capture/PCK/empty-cwd/GUI/teardown checks remain. Actual package execution remains separate evidence; this review does not claim it passed.

## Independently rerun

`python3 tests/plains_regional_art_capture_test.py`:3tests including8binding mutations,0.001s,OK; original prior negative cases retained. Log `build/plains_regional/review_binding_counterexamples.log`.

`python3 -m unittest discover -s tests -p test_visual_director.py`:original24tests,7.267s,OK. Log `build/plains_regional/review_legacy_visual_after_binding.log`.

**ACCEPT_SCOPED adapter/test correction**, no artistic admission or full-CI/package/user/device claim. The independently observed regional art rejection remains unchanged; recovered normal-rate movie can prove actual route evidence, not cure the failed landscape.
