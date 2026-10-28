extends RefCounted
## Bounded actual-runtime passive probe after the real combat/reward transaction.
## The core-choice UI stays open. A disclosed real resonance debit only makes
## room in a full bar; no HP/position/clock/ability/token or resource grant writes.

static func sample(app: DemoApp, id: StringName) -> Dictionary:
	var runtime := app._item_runtime
	var energy := app.controller.combat_energy
	var owned := app.build.inventory.instance_for_definition(id)
	var map := String(runtime.map_key())
	var maps: Dictionary = owned.effect_state.get("recovery_maps",{}) if owned != null else {}
	var row: Dictionary = maps.get(map,{})
	return {"clock":runtime.now(),"physics_frame":Engine.get_physics_frames(),"motor_steps":app.player.motion_steps,"actor_instance":app.player.get_instance_id(),"session":app.controller.session_id,"actor_epoch":app.lifetime.actor_epoch,"resonance":energy.current,"capacity":energy.capacity(),"hp":app.controller.actor_resources.health.current,"hp_capacity":app.controller.actor_resources.health.capacity,"map":map,"recovered":float(row.get("recovered",0.0)),"serial":int(row.get("serial",0)),"last_combat":float(runtime._economy.get("_last_combat")),"instance":String(owned.instance_id) if owned != null else "","parameters":runtime.effect(id),"core_modal_open":app.progression_modal.opened,"campaign_phase":int(app.campaign.phase),"abilities":Array(app.campaign.abilities),"paused":app.get_tree().paused}

static func run(app: DemoApp, item: ItemDefinition) -> Dictionary:
	var tree := app.get_tree()
	var id := item.stable_id
	var result := {"scope":"Explicit real-frame passive probe with core-choice modal retained; optional CombatEnergyState debit is disclosed fixture, not a natural skill or resource grant","kind":"G07_idle_recovery","supported":id==&"G07","frames":[],"grants":[]}
	if id != &"G07": return result
	for unused: int in 4: await tree.process_frame
	var parameters := item.parameters_for_level(1)
	result.parameters = parameters
	result.before = sample(app,id)
	var energy := app.controller.combat_energy
	var before_debit := energy.current
	var space := minf(float(parameters.max_recovery_per_map),float(parameters.resonance_per_s)*1.2)+1.0
	var debit := minf(before_debit,maxf(0.0,space-(energy.capacity()-before_debit)))
	var debit_id := "canopy_gold_probe_debit/"+app._run_receipt_prefix
	var accepted := debit <= 0.0 or energy.consume(debit_id,debit)
	result.debit_fixture = {"event_id":debit_id,"amount":debit,"before":before_debit,"after":energy.current,"accepted":accepted,"method":"CombatEnergyState.consume; no direct assignment or grant"}
	result.start = sample(app,id)
	var old_grants: Dictionary = energy._grants.duplicate(true)
	var deadline := app._item_runtime.now()+float(parameters.idle_delay_s)+1.2
	var maximum_frames := ceili((float(parameters.idle_delay_s)+1.5)*60.0)+60
	app.controller.router.clear("canopy_passive_probe")
	tree.paused = false
	for unused: int in maximum_frames:
		await tree.physics_frame
		await tree.process_frame
		result.frames.append(sample(app,id))
		if app._item_runtime.now() >= deadline: break
	tree.paused = true
	app.controller.router.clear("canopy_passive_probe_finished")
	result.after = sample(app,id)
	for receipt: String in energy._grants:
		if not old_grants.has(receipt): result.grants.append({"receipt":receipt,"amount":float(energy._grants[receipt])})
	return result
