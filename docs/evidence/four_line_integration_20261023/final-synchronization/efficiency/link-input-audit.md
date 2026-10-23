# a074 input materialization: link existence versus byte consumers

Read-only audit of the actual CI report at `/workspace/scratch/ci-pr106-a074/raw/gunman-rush/gunman-rush/build/verification/production-ci/inputs.json`.

- Exact commit: `a074a709ffa64c1382d73d2dab6dcff673222728`.
- Report SHA256: `8f4d06b975807e2dea9c452efa09ade5ad280bb9e8b2fbaebdd6cdc651e4e363`.
- Actual materialization: **3062 paths, 3,293,896,939 bytes, 341.816 seconds, 2 rounds, 93 prefetch batches**.
- Round1 actually materialized2437paths/2,531,631,689bytes; round2 exposed625more paths/762,265,250bytes.
- This is preparation of existing evidence, not generation of new game content. All byte totals below are uncompressed file bytes, not measured network wire bytes or compressed Git pack size.
- No source/CI changes, native execution, lazyfetch or media downloads performed for this audit. The416 exact-a074 quality JSON records were read through local Git objects with `--no-lazy-fetch` to identify actual hash fields.

## Classification from real required_by plus exact quality fields

|Set|Paths|Bytes|Meaning|
|---|---:|---:|---|
|All materialized|3062|3,293,896,939|Actual report, not estimated closure|
|Any Markdown local-link existence edge|1190|2,015,911,271|May also have stronger consumers|
|Only Markdown local-link existence edges|893|1,876,183,641|57.0% of all materialized bytes; no selected byte/hash consumer in current preflight contract|
|Only-link media/archive subset|233|1,807,034,121|Images/audio/video and `.zip/.gz/.tar/.7z`; explicit extension definition in audit.py|
|Actual quality SHA fields|1190|1,395,518,932|Record evidence.sha256, asset source_sha256 or associated_files.sha256; bytes genuinely read+hashed|
|Quality SHA media/archive subset|309|1,284,336,488|Must remain byte-validated under present checks|
|Markdown links AND quality SHA|108|138,783,673|Intersection: existence optimization must not suppress real hashing|
|Intersection media/archive subset|19|122,759,550|Same stronger-consumer rule|
|Markdown source content itself|987|3,528,538|Must still be read for nonempty/content/link extraction|

The two1190path counts are coincidental and are not the same sets. SHA classification is based on actual record fields at a074, not merely a quality-looking filename. `quality.py:123–124`,`:350–351`,`:365–378` really read and hash these fields; runtime_paths and user_acceptance_evidence are separately presence-only and were not mislabeled SHA.

**Minimal check_docs-only opportunity:** of the893only-link targets,3small JSON targets (8156bytes) are also skill `.is_file()` consumers under check_quality. Leave those hydrated. The other **890paths/1,876,175,485bytes** can be considered for the narrowly scoped existence-by-Git design below. Accounting for duplicate blob identities still needed by other materialized paths, these contain **871exclusive OIDs/1,864,133,451bytes**;869of these OIDs/1,864,128,011bytes were initially missing locally. This is a defensible uncompressed-object opportunity, not a promise to remove1.864GB of wire traffic or a prediction of exact seconds saved.

## Largest five targets required only for links

|Target|Bytes|Markdown consumer|
|---|---:|---|
|`docs/evidence/parallel_integration_01/ci07/original-diagnostics.zip`|80,604,499|`docs/evidence/parallel_integration_01/ci07/README.md`|
|`docs/evidence/plains_redesign/final_current/raw/build/plains_redesign/matched_movies/before/creek_growth/gameplay.mp4`|79,202,326|`docs/plains_redesign_delivery.md`|
|`docs/evidence/plains_redesign/final_current/raw/build/plains_redesign/outer_no_live_png_movie/gameplay.mp4`|75,450,468|`docs/plains_redesign_delivery.md`|
|`docs/evidence/forest_playable/final/browser_gui_and_retained_failures.tar.gz`|69,218,460|`docs/evidence/forest_playable/README.md`|
|`docs/evidence/creative_system/media/previous-visual-85s.mp4`|63,797,099|`docs/quality/creative_system/README.md`|

These five alone total368,272,852bytes. None has a quality SHA field or any stronger required_by edge in this report. This does **not** authorize deleting or rewriting the files or their historical evidence.

For comparison, true SHA consumers include `enemy_encounter_v2/movie02_gameplay.mp4`89,006,276bytes (`V3-ENCOUNTER-V2-01.json`), `forest_focus_routes03/final_validation/fixed80-and-three-failures.zip`62,772,154bytes (`FOREST-FOCUS-ROUTES-03.json`), and the visual_director creek movie53,828,015bytes (`VISUAL-DIRECTOR-01.json`). Their actual bytes remain required. Full top5 per set and every record field are in summary.json/classified-materialized.json.

## Why historical Markdown causes a large download

`harness.py:180–184` enumerates tracked and untracked nonignored paths, including sparse tracked evidence Markdown. `production_loop.py:481–484` selects **every `.md` in that enumeration** whenever the docs check is selected; it is not limited to current authority documents. `markdown_links()` at`:417–428` requires the Markdown content, reads each local target and adds that target as a required file. Historical evidence README files therefore enter on round1; their local links reveal further media on round2. It is a whole-repository Markdown scan rather than a recursive link walker, but its multi-round effect is similar.

The real consumer `check_docs.py:24–43` likewise scans all filesystem Markdown (except .git/.godot/__pycache__ and root build), reads/nonempty-checks each document, then only calls `exists()` on each local link target. It does **not** open an MP4/ZIP target or validate its contents. Thus publishing those large bytes solely to answer a link-existence question is unnecessary IO under the present checker semantics. Directory links already use one representative in preflight (`production_loop.py:382–399`), not all directory media; the main observed cost is explicit links to large files.

## Smallest safe later change (not implemented)

1. Add a narrow link-target existence resolver to check_docs. For an ordinary present local target, preserve filesystem checks and reject symlink components/wrong type. For an absent target, permit only an exact regular-file entry at the pinned HEAD with identical stage0index mode/OID and skip-worktree state. Ordinary worktree deletions, unmerged/staged changes, symlinks, wrong mode and missing Git paths still fail. A directory link can use exact Git tree/index structure without creating an empty placeholder. Read every Markdown source's real bytes as today.
2. Mark **only these check_docs local-link edges** as existence-only in the existing preflight. Keep selected check literal/directory inputs, quality SHA fields, skill is_file edges and all source/runtime consumers as stronger dependencies; any stronger consumer wins and still materializes. An existence result should state Git-backed presence/bytes-not-read, never content quality or a test that did not run. Do not infer this distinction from file suffix or historical age.
3. Validate against the exact a074 input set before adoption: unchanged docs link verdicts on ordinary checkout; actual sparse-only link succeeds without obtaining its blob; ordinary deletion/staged mismatch/symlink/wrongmode/missing target all reject; an overlapping quality-SHA video still downloads and fails a changed hash. Current Markdown content/nonempty tests and all original quality assertions remain. Expected file-set ceiling is890fewer published paths in this recorded set, with up to869initially-missing exclusive OIDs avoided; report actual postchange bytes/process/networkfetch/time rather than asserting those ceilings as achieved.

Current report required_by is the existing declared/discovered consumer contract, not a newly proven complete static dependency graph. The proposed finite change needs these negative tests and current consumer closure review. It is a preparation optimization, not permission to remove historical records, weaken SHA checks, reuse testPASS or alter the current running CI.

Reproduction: `audit.py` only reads the saved report and exact local Git JSON objects; `summary.json` contains totals/top5; `classified-materialized.json` contains every materialized row with separate Markdown, SHA and presence fields.
