# Frozen R2 Home layout and original assertions

The user explicitly replaced the flat R2 settlement with a multi-tier settlement
and an eastbound road in R3 feedback 9/10. `replay.json` lists byte-identical
originals from commit `0fab13fcc446bf9abd3c6beaf21e0fc5b76bd9ad`.

These `.source` files preserve history and are not runtime code. Reproduce the
old assertions in the complete frozen source, including its dependencies:

```sh
git worktree add --detach /tmp/gunman-home-r2 0fab13fcc446bf9abd3c6beaf21e0fc5b76bd9ad
cd /tmp/gunman-home-r2
python3 tools/run_underworld_home_tests.py
bash tools/godot.sh --headless --fixed-fps 60 --path . --audio-driver Dummy --script tests/home_app_runner.gd
bash tools/godot.sh --headless --fixed-fps 60 --path . --audio-driver Dummy --script tests/home_ui_tests.gd
```

A command is not a recorded pass. The original standalone Home UI fixture was
already known to emit leaked-resource diagnostics after its 27 functional
assertions; the current R3 run retains this failure too. No teardown waiver is
introduced here.

The current default is tested separately by
`python3 tools/run_underworld_home_terrace_tests.py`. The original 27/19 Home
business assertions remain in their current entry points with only coordinate
queries and the obsolete timed-axis travel driver adapted to the authorized
layout. The original R2 97-assertion walk-only fixture remains unchanged in its
original path and in this snapshot; it is explicitly a frozen-layout replay,
not proof of the current terrace route.
