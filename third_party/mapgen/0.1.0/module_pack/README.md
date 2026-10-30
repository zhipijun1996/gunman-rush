# Module package integration

The ZIP is generated from the single map-edit Module library. Unzip it into `res://module_pack/` in a Godot host, or read its top-level `catalog.json` from map-gen. Never edit it as another source library. Pin the package version and SHA256 in downstream project configuration.

`manifest.json` records package/schema/Foundation/source versions and checksums for every included file. Foundation specification 1.2, Foundation model 1.0 and generationContract v2 are separate version numbers. `catalog.json.modules` contains stable IDs, current content versions, aliases, region/use, Block size, rectangular footprint, source bounds/origin offset, actual scoped directed routes, ability and initial configuration requirements, explicitly allowed configurations, runtime scenes and evidence references. Designs excluded from runtime have specific reasons in `catalog.json.excluded`.

map-gen chooses mirroring and any connected-Port subset for every base Module. There is no per-module mirror eligibility switch and no mirrored copy. It must mirror the **complete** Module content (including directional mechanics, motion, rewards and references), Ports and Routes together, place gear closures at every unused Port, and check the remaining routes against those closures. `configurations` and route `validation` describe original certification witnesses, never a generation whitelist. Mirroring, partial connections, gear closures and arbitrary seams remain UNKNOWN until separately checked. Initial Port permissions and ability/profile requirements still apply; later mechanism states do not grant an initially forbidden ingress.

## Dependencies and clean installation

No player scene, original game engine, historical game project or experiment workspace is embedded in the ZIP. Shared actor/Cell/assets are installed by hash from the upstream game commit in the lock. Python's standard library is sufficient for the installer:

```sh
python3 module_pack/integration/install_host.py --target /path/to/godot-project
```

The default lock is `runtime/host-lock.json`: the native `12f6cb006d7119598e3235f4ca4f7323e4c9d092` profile used by scoped route qualification. It is a bounded dependency closure, not the complete game repository. `--source /path/to/host-checkout-or-cache` copies only declared, hash-matching files; omission downloads exact upstream files. Conflicting installed versions and missing/changed files fail explicitly. The copied project works after the cache is unavailable. Godot 4.7.2 stable is the validated engine; see the engine SHA in the lock and acceptance evidence.

`runtime/host-lock-current-game.json` declares the read-only checked game head `5f55716a838a754a938997920ff18cb3b17452b5`. This profile has native scene/collision/mechanism/reward/external-player API integration checks. Full route/robustness qualification on that newer host is still pending; the original route evidence remains tied to the native profile. To inspect/install that explicitly chosen compatibility profile:

```sh
python3 module_pack/integration/install_host.py --lock module_pack/runtime/host-lock-current-game.json --target /path/to/current-game
```

When integrating into an existing game, keep its own `project.godot`, player, lifetime and services. The installer verifies matching existing files and refuses silent overwrites of incompatible files. Do not create duplicate global game classes inside the package. Old fixture source path strings inside legacy metadata are immutable provenance labels; portable profile verification uses the package's `runtime/player-profiles.json`, not those former files.

## map-gen reader

The read-only checked map-gen commit is `c2ac2c3625f659364b187592c836c5ff2bceb892`. Its current Python prototype has no released package-import API. `integration/map_gen_reader.py` supplies a bounded adapter to its `prototype.model` template/Port conventions:

```python
from map_gen_reader import read_library, validate_placement, routes_for_abilities
library = read_library('/path/to/unzipped-package')
template = library['b31-n06-fourport-two-low-ingress']
selected = [p['id'] for p in template['ports'][:2]]
configuration = validate_placement(template, selected, mirror=True)
usable_routes = routes_for_abilities(template, {'jump', 'recoil'},
                                   connected_port_ids=selected, mirror=True)
# prototype.model.placed_ports(template, origin_x, origin_y, mirror=False)
```

Insert these templates after importing the model; do not call the prototype's `generate.prepare_library()`, which overwrites `LIB` with placeholders. The adapter maps `shot_recoil` to its `recoil` spelling; it preserves `wall_climb` rather than pretending the prototype supports it. Only exact witnessed ability sets are returned. For a module that declares a native tuning/fixture, also pass its exact ID as `native_profile_id=…`; omitting or mismatching that profile returns no routes. The template retains the complete `initial_configuration` and `host_profile`. The existing prototype generator must stop reading its old per-template `allow_mirror_x` flag and use a uniform complete-content transformation. This adapter deliberately exports no such switch or `allowed_configurations` whitelist. `validate_placement` checks duplicate/unknown IDs, closure IDs and the existing base layout; it accepts partial connections and mirrors without certifying them. `routes_for_abilities` filters route endpoints against the selected subset and marks changed placements UNKNOWN, preserving the original evidence fields. That endpoint filter is only a candidate filter: map-gen must also check gear geometry against every remaining route. This package does not modify the downstream repository.

Port `local2` coordinates are doubled Block coordinates relative to the owned rectangle's top-left. At integer Block origin `(x,y)`, `world2 = 2*(x,y) + local2`. Matching still requires opposite faces, equal surfaces, initial permissions and a separately verified seam.

## Rewards and purpose

`catalog.json.modules[*].reward_sites` is the complete existing compiled `reward_sites` array: stable local `id`, `position: [x,y]`, claim `region: [x,y,w,h]`, and `amount`. Coordinates use the same Godot pixel axes and original source origin as compiled Cells; apply `sceneOriginOffsetPixels` and the instance transform exactly once. Reward identity is scoped by stable Module ID and instance ID, not a regenerated coordinate hash.

Use only `Route.resourceProfile.requiredRewards` for route associations. Existing explicit declarations are retained; missing export metadata is projected from the exact matching qualified canonical case's existing `required_rewards`. It is not inferred from proximity, a route title, expected currency totals or the presence of a chest. An empty list means the retained route does not require the reward, not that an optional claim is impossible. Missing/unconfirmed associations appear in automatically generated `reward-association-gaps.json`; modules and chests remain present. HQ04 and S13 export `L-to-L → ["reward"]` from their qualified native inputs.

`purpose` marks `boss_arena` and `boss_approach` from existing explicit native family metadata (future source documents may declare `purpose` directly). Every Module has the same ordinary structure. `entryPortIds` is derived from actual exported directed-route starts and initial ingress permissions, rather than all physically present Ports. For the current plains Boss arena it is `["entry"]`; its physical `exit` remains exported but has no qualified incoming route. This is an arrival interface, not certification of the Boss fight or arbitrary external seams.

## Main game loader and external player

```gdscript
const ModuleRegistry=preload("res://module_pack/integration/module_registry.gd")
var registry=ModuleRegistry.new()

func load_generated_room(existing_player: PlayerController, world: Node2D, services: Dictionary) -> void:
    var opened: Dictionary=registry.open("res://module_pack")
    assert(opened.ok)
    # Derive from the saved map/node identity; never use the current array index.
    var stable_instance_id="run-42/map-node-17"
    var result: Dictionary=registry.instantiate_module(
        "b31-n06-fourport-two-low-ingress", stable_instance_id,
        Vector2i(7,-3), world, existing_player, services)
    assert(result.ok)
    var port: Dictionary=result.instance.world_port("A")
    print(port.position)

# services must contain the host-owned policy: FrameDamagePolicy,
# lifetime: DemoLifetime and wallet: RunWallet. Native Note/region-chest
# consumers also require meta: MetaProgression and region_state: PlainsRegionState.
```

The registry takes a Block origin for the owned rectangle, not an old editor-canvas origin. `instance.position = world.to_local(originBlocks*blockSize + sceneOriginOffsetPixels)`; `sceneOriginOffsetPixels = -bounds.position`. `world_port()` returns true global boundary positions. Parent transforms must be translation-only. Duplicate live instance IDs and unknown interface layouts fail. The registry loads the authored `base` scene; map-gen is responsible for materializing its fully transformed content and gear closures. It does not implement mirroring by applying a negative parent scale to only part of the scene. Save the module ID, exact content/package version, stable instance ID, origin and configuration with the generated map.

The host creates/configures its existing player once before binding. Binding never spawns another player, applies a tuning profile or refills resources. Read each entry's `initialConfiguration`: when a native fixture/profile is required, configure the actor at initial creation using the declared native profile and `runtime/module_runtime/native_profile_v5-eeef5b9dc854.gd.initialize_once`; passing a mismatched existing actor fails. Do not initialize that profile at a room seam. The helper verifies the package's exact profile declaration and rejects initialization after the player's first tick.

Enemy/damage identities and reward transactions are namespaced by stable instance ID. Multiple instances share the supplied native damage policy and wallet while retaining independent enemy targets. Unload through `registry.unload(instance_id)` and wait for the queued node to exit before reusing that live ID. Cleanup releases only that instance's native damage registrations; shared player resources stay with the host. Saved per-module mechanism/enemy state and arbitrary room chaining are host integration work, not supplied whole-game persistence.

## Verification

`evidence/module-production/portable-runtime.json` binds the current source hashes, runtime fingerprint, pinned host and engine. Acceptance imports real scenes in a clean extracted project, checks every module's collision shapes/one-way flags and translated Ports, binds the external actor without resource resets, exercises actual body collision, native projectile-to-bell delivery and idempotent native reward grants, and checks independent shared instances. `strace` verifies no runtime reads from the authoring repository or former experiment/fixture paths. Latest-game API compatibility is reported separately. Historical physical qualification is addressed by immutable Git/archive references, never by missing local experiment folders.

## Run the included playable sample

For a fresh sample project, unzip the archive under `sample/module_pack/`, install its locked dependencies, and create this minimal `sample/project.godot` (an existing game keeps its own project configuration):

```ini
config_version=5
[application]
config/name="Module package playable sample"
run/main_scene="res://module_pack/integration/playable_sample.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[physics]
common/physics_ticks_per_second=60
[rendering]
renderer/rendering_method="gl_compatibility"
```

```sh
python3 sample/module_pack/integration/install_host.py --target sample
Godot_v4.7.2-stable_linux.x86_64 --headless --path sample --editor --import
Godot_v4.7.2-stable_linux.x86_64 --path sample
```

A/D moves, Space jumps, mouse release shoots, E requests native pickup interaction, and R restarts this sample host. `-- --module STABLE_ID` selects another included module; the sample configures a new actor at birth from that module's declared native profile. It never changes an existing game's player at a seam. The automated sample test uses actual keyboard/mouse events and observes accepted jump and shot signals, not a replacement movement model. Godot-generated `.uid`/`.import` files beside declared resources are disposable caches; package verification ignores only those known generated companions and still verifies every original file.

Some scoped route witnesses require explicit neighbor geometry. Inspect `route.validation.testNeighborFixtures` before selecting/connecting that route. The three-enemy module uses `[272,-32,96,12]` and the relay-lift module `[144,-32,96,12]` for A→B's external upper platform, in original local pixel coordinates. These are evidence conditions outside the owned rectangle, not extra geometry installed by the runtime. A generic neighbor with merely the same surface label is not automatically certified.
