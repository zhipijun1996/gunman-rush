# Ordinary presentation lifecycle refactor handoff

Implementation scope: EnemyPresentation, PrototypeEnemyPresentation, four forest hosts, RootBellPresentation, WindchimeEnemyVisual/PixelPlainsEnemy/UnderworldEnemy; PlainsMotion02 and ForestMotion02; generic accepted-hit template/particle teardown. No engine execution by this agent. Production source is frozen for the root's tests.

Common component is `scripts/presentation/enemy_presentation_lifecycle.gd`:

- `bind(actor,host,initialize_callback,health_callback=Callable(),motion=null,sample=null,owns_sample_clock=false) -> bool`: requires initialized Actor snapshot; same actor/host/health bind is idempotent, changed context disposes the old component binding.
- `sync_initialize()`: fresh Actor read-only snapshot; only a changed HealthState epoch invokes reset callback. Initialization remains immediate while paused via one host health listener.
- `advance(delta) -> bool`: sync then validity/pause/finite positive delta guards; one optional motion and exactly one explicitly-owned sample clock advance. Host-specific clocks and terminal policy remain in each host.
- `synchronize()`: no fabricated initialize event; same-epoch call preserves accepted hurt/death progress and only refreshes motion spatial baseline/facing. Hosts expose `synchronize_presentation()`; scene/UW expose `presentation_remains()`.
- `own_cleanup(Callable)` and `dispose()`: explicit owned callbacks, health listener, owned sample and motion teardown. Generic HitTemplate/Particles now expose idempotent dispose; bark shield receiver uses a stored exact receiver and named callback registered for cleanup.

Motion adapters accept `sync_epoch(actor,snapshot={})`, `synchronize(actor,snapshot={})`, `advance(actor,delta,snapshot={})`, and `dispose()`. They consume Actor.presentation_state raw phase/elapsed/durations, position, facing, epoch and terminal. No phase vocabulary, angle, source image, mesh topology or gameplay movement changed. Existing offscreen body culls remain in their pure draw helpers.

Prototype now uses the existing EnemyPresentation lifecycle/clock path and an overridden custom body-pose hook; its parent PlainsMotion/weight/lean/frame weights are no longer advanced for rendering. Windchime's anonymous health listener is replaced by the lifecycle's named callback. Underworld no longer calls that parent ready path; it reuses Pixel's local timing/visibility function after one lifecycle advance. Four forest hosts no longer copy connect/disconnect/epoch dispatch logic.

Cold terminal behavior: original initialize/restore settled policy now also runs on the first bind. Forest .38s settled; prototype .6; RootBell .8; Pixel/UW .65/hidden; windchime hidden; generic scene _death_time=1 with original initialization weight ONE. Authored scene/UW H/D sample and original Remains renderer still own their corresponding body/death. Same-epoch accepted death does not invoke an initialize callback. Legacy host _clock is preserved on health initialization where it was previously preserved; prototype/Forest existing epoch clock resets remain.

Root ownership: binding/profile/installer routing, restored full-pose boundary, Remains policy, and the final scene-body/UW body-key draw edits. Those root edits in EnemyPresentation/UW/Pixel are not to be overwritten by this agent. Binding-plan owns Actor/Definition/factory logic; enemy-review owns the structural test runner.

Verification facts: git diff --check passed. Root native-01 parsed the lifecycle and reported 15 factory resource-detachment assertion failures, not lifecycle script errors; that failure source remains preserved. Named bark callback cleanup was then fixed in a root-approved source window and awaits the next root native run. No art, timing or device quality is signed here.

Rebinding scope: the component supports explicit dispose/rebind; current production factory replaces renderers with newly assembled hosts. This does not claim an already disposed host can hot-reconstruct every sprite/frame/Remains resource without reassembly.
