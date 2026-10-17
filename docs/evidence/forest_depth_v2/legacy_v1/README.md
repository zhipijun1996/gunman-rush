# Forest v1 frozen regression fixture

This fixture is **historical forest v1**, exactly source commit
`bee850c66b2f402d644d7daa4c13db91c8abe8f8`. It cannot certify current forest v2,
its topology, enemies, bosses, route drivers, or new formal input coverage.
No original test, wrapper, harness profile, assertion, cap or marker was edited.
Nothing in this directory records a native execution or passing forest checks.

`source.tar.gz` retains original raw files in scripts, scenes, resources, config,
tests, tools, shaders, addons, project.godot, export_presets.cfg and .gitignore.
The old H-slice's authority reader also needs the original player_actions docs,
world_regions.json, current_state.md and its three linked quality contracts;
these are retained byte for byte. `manifest.json` records their SHA256 and Git
blob IDs, plus the original eight check definitions from the archived profiles.

`inventory.json` lists **every tracked baseline file** with original mode, Git
blob and size. Large unrelated historical evidence, preview and tracked build
files are inventory-only; this is not a complete old checkout. Their original
blob IDs are provenance, not a claim that their bytes are bundled here.

All 654 original assets are restored from same-path current files only when both
SHA256 and the genuine Git blob identity match. There is no duplicate 192.5 MB
asset archive. Changed/missing files must have exact old raw bytes retained as
`asset_blobs/<original Git blob ID>` or restoration refuses. Wrong bytes under an
old blob filename also refuse; no substitution or checksum bypass is supported.

The source archive includes authentic baseline commit and tree Git objects.
Restoration makes a standalone shallow Git metadata directory and independent
index from that original tree. `git rev-parse HEAD` and `git ls-files` inside old
wrappers therefore refer to the genuine old commit/tree, never the enclosing v2
worktree. Index paths, modes and blob IDs are compared to the full inventory.
There is no fabricated commit, Git remote, shared writable index or object
alternate. Inventory-only evidence blobs are deliberately not materialized.

Reconstruct without starting Godot:

```sh
python3 tools/forest_legacy_fixture.py --restore build/forest_depth/acceptance/v1-reconstruction-NEW
python3 tests/test_forest_legacy_fixture.py
```

Explicit native invocation (requires the original Godot 4.7.2 toolchain):

```sh
python3 tools/run_forest_v1_regressions.py \
  --check forest-traversal --check forest-region-matrix \
  --output build/forest_depth/acceptance/v1-native-NEW
```

The runner requires explicit check IDs. It fresh-imports under the archived
H-slice's original 90-second import cap, then invokes selected **original argv,
timeouts and completion markers** through the archived `harness.run_check`.
The original `--skip-import` argv is retained after successful fresh import.
The current global engine lock protects toolchain use; original wrappers use
fixture-local locks to avoid recursive locking. Engine cache, config and saved
data are isolated. Sources/assets are verified before and after every check.

Outer logs and `report.json` stay in the requested fresh build directory; all
original inner native logs/captures remain under `fixture/project/build` and are
indexed with SHA256. A failure, timeout, source change or missing marker remains
a failure. No old output is reused. These tools do not alter the default harness
or register v1 as v2 coverage. The parent must separately register history and
strong new v2 consumers when ready.
