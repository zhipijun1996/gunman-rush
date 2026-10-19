# Runtime V3: region presentation comparisons

Preferred anchors are **Underworld (4)** and **Cavern (5)**. Each now has Plains, Forest and Gear art environments in the same playable comparison layout. Forest/Gear are comparison previews; no formal region, ability or progression is opened.

`final_switches_and_cli/biomes.log`: **1706 checks, 0 failures, 16 added consumers** (2 styles × 2 additional environments × 4 seeds). Actual UI button callbacks, native B key cycles while paused, and a real mouse click into the Forest button are exercised. Each switch and return preserves exact player/camera position, player/actor/session/epoch, Motor step count, TileSet identity, atlas coordinates, collision instance IDs, layout, tuning, health and shot charges. Deterministic geometry output is rebuilt from the same seed and remains identical. Stale movement/action requests are cancelled through the existing input contract.

The test invokes the real scenery fourth-argument API and the terrain/one-way region palette hooks. Underworld/Plains intentionally retains its original material; other 4/5 region combinations use the admitted region ramps. These are nondestructive palette changes, not new collision or TileSet topologies.

The separate actual-CLI logs pass Underworld/Gear, Cavern/Forest and unsupported Basic/Forest → Plains fallback. Four named preview scenes also instantiate the requested 4/5 Forest/Gear variant, sharing the original layout. Unsupported styles automatically return to Plains and disable the other environment buttons.

## Reused movement proof

The 20 lower-route round trips and 80 complete upper-module visits/returns remain in `../runtime_v2/`. This presentation phase does **not** repeat or relabel those routes as new region gameplay. `source_and_reused_physics.json` verifies that StyleLayout, StyleTerrain and StylePlatform are byte-identical to that proven V2, and that formal PlayerMotor, Controller, JumpAbility, tuning and input sources are unchanged from the base Git source. Switch checks additionally prove that the active TileSet, cells, collision instances and actual Motor consumer remain unchanged.

Forest/Gear have no formal region mechanics or modules in this experiment. Shared geometry is intentional for visual comparison. Six genuine final visuals and generated region assets are independently produced and reviewed by the parent task; runtime invariants and non-null materials do not establish visual quality or asset completeness.

## Reproduce

```sh
python3 tools/run_style_exploration_tests.py --skip-import --biomes-only
```

Normal runner invocation additionally runs the existing complete lower/upper movement suite. Play the ordinary style lab, select 4/5, then choose Plains / Forest / Gear. B cycles those three on the preferred anchors. Other styles retain Plains. CLI supports `--style=cavern --biome=gear --sample=0`. Every GPU capture receipt now includes `biome` alongside camera/avatar positions and `traversal_claim=false`.

## Preserved observations

The first run incorrectly expected a material on original Underworld/Plains and attempted a mouse GUI click in Godot's headless default 64×64 Window. Both observations are retained. The palette assertion now explicitly checks the original-material exception; the GUI fixture uses 1280×720, consistent with the existing repository touch runners. An isolated native probe confirmed a real button hover/press/release at that resolution. The second, one-failure window observation and the first complete passing switch run are also preserved.
