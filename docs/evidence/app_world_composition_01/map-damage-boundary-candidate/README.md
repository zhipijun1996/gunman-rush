# P1 map damage ownership candidate

External only. Base is c8d39551 with all three frozen attack-cancel candidate leaves overlaid (including its unchanged EnemyActor leaf). This patch changes only App, GeneratedDemoStage and the existing DemoContactEmitter. Apply cancel first, then this patch. candidate.json contains exact input/output hashes. No tests, inputs, budgets, production main files or native engine were changed/run.

## Actual ownership and order

GeneratedDemoStage.bind_damage_context takes the existing controller, policy, lifetime, segment and explicit connected_region policy, plus two narrow Callables. It owns one synchronous operation:

1. Add existing generated anchors, in original order and with original IDs.
2. Assign assembler.world_dangers(), then assembler.setup_damage().
3. Run the original setup_shot_latches; return false immediately on its failure.
4. Only if connected, connect the existing assembler shortcut signal. Bind lifetime.stage_epoch and lifetime.epoch here, after successful latch setup, exactly as before. The callback is the original App recording method; no Stage-specific duplicate recording logic is introduced.
5. Synchronously call the supplied layout_record with the original shot_latch_plan. App's callback invokes its original Manifest operation, with stage_index read here. The callback is not saved and no frame/await is introduced.
6. Read connected-only static hazard records and then static danger rectangles. Construct each emitter, parent it, set its position, and only then assign connected-only fall_plane/metadata in the same order as before.

App retains the original failure status and abandon_run/return at the same synchronous call boundary, then the original physics-frame await, token guard and entry-anchor activation. Fixed-stage fallback, later dynamic saw and enemy/Boss contacts, presentation, Manifest outputs beyond this one call and damage rules remain unchanged. Stage never receives App, Director or Session as a service object. The signal retains the same App-bound recording callable as before; the transient layout callback is not stored.

DemoContactEmitter.attach is the original _contact constructor body with only policy/controller/kind parameter names substituted. App._contact is a thin bridge used by all its existing callers and the real tests/forest_depth_ecology_trace.gd consumer. Stage uses the same factory. Parenting remains before position and metadata writes, retaining _ready/physical_contact hookup timing and default interval 0.7. Existing environment_rect remains unchanged: it deliberately returns an unparented positioned rectangle for different callers and must not be silently replaced by a parented factory.

Forest assembler setup_damage remains its existing no-op; Forest's authored surface hazard records retain their own policy, rather than adopting Plains pit-plane inference. No extra validation, empty-state normalization, new registry or idempotency promise is introduced. Calling the Stage operation twice remains outside the existing one-time load protocol.

## Evidence and limits

prepare.py reconstructs all three whole input files exactly and reverses the moved map block and contact constructor body exactly. Actual git apply/check/apply-reverse in an external temporary tree matches all three originals/candidates. This is source-preservation evidence, not native or behavior acceptance. Tests are unmodified. Relevant existing consumers include tests/underworld_plains/test_underworld_hazards.gd (actual App accepted generated_spikes damage), tests/forest_hazard_records_runner.gd (authored Forest records), tests/underworld_plains/test_underworld_damage_r3.gd (surface versus pit-plane semantics), tests/plains_interactive_lifecycle_runner.gd (actual latch/reload lifecycle) and existing generated-consumers/core lanes. Root owns native validation and independent review.
