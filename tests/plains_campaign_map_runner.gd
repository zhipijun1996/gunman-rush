extends SceneTree
var assertions:=0
var failures:=0
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		printerr("FAIL: "+message)
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func fixture(seed_value: String) -> void:
	paused=false
	if is_instance_valid(app):
		if not await load("res://tests/audio_teardown.gd").drain_world(app):
			failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
		app.free()
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_plains(seed_value),"two-map formal departure starts")
	await frames(8)
func run() -> void:
	corpus()
	await fixture("two-map-ledger")
	var first:=app.stage as PlainsRegionStage
	var health:=app.controller.actor_resources.health
	var mini:=first.boss.get_node("Encounter") as WindkeeperEncounter
	check(first.generated.manifest.difficulty=="intro" and mini.health.capacity==16 and mini is BellstriderEncounter,"first whole map is simpler with independent sixteen-HP Bellstrider")
	check(app.director.profile.stages_per_biome==2 and app.director.offers.is_empty(),"two worlds do not restore room-exit chains")
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"first map manifest is replayable")
	check(not first.region_state.explored.is_empty(),"ordinary spawn observation reveals local fog")
	check(first.map_view.visible_areas().all(func(a: Dictionary): return a.role not in ["boss","merchant","challenge_reward"]),"initial fog hides undiscovered Boss/camp/rare locations")
	var fog_before:=first.region_state.explored.duplicate(true)
	check(app.open_region_map() and paused and app.map_modal.opened,"actual map opens modal and pauses world")
	var clock:=first.assembler.modules[0].clock
	await frames(4)
	check(is_equal_approx(first.assembler.modules[0].clock,clock),"large map does not advance hazards")
	var canvas:=app.map_modal.canvas
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	wheel.position=canvas.frame().get_center()
	canvas._gui_input(wheel)
	check(canvas.zoom>1,"wheel input enlarges map")
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	canvas._gui_input(press)
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(100,40)
	canvas._gui_input(motion)
	check(canvas.pan.distance_to(Vector2(100,40))<1,"real drag input pans expanded map")
	canvas.zoom_at(1000,canvas.frame().get_center())
	check(canvas.zoom==6,"zoom is bounded")
	canvas.reset_view()
	check(canvas.zoom==1 and canvas.pan==Vector2.ZERO,"center control resets view")
	for i: int in 2:
		var touch:=InputEventScreenTouch.new()
		touch.index=i; touch.pressed=true; touch.position=Vector2(200+i*200,200)
		canvas._gui_input(touch)
	var finger:=InputEventScreenDrag.new()
	finger.index=0; finger.position=Vector2(220,200)
	canvas._gui_input(finger)
	finger.index=1; finger.position=Vector2(450,200)
	canvas._gui_input(finger)
	check(canvas.zoom>1 and canvas.zoom<=6,"two-finger input actually magnifies the map")
	check(first.region_state.explored==fog_before,"opening/zoom/pan never reveals unexplored places")
	app.close_region_map()
	check(not paused and not app.map_modal.opened,"closing map resumes one world")
	# A claimed box is local to map 1; map 2 has different service identities.
	app.player.reset_at(first.chests[0].position)
	await frames(2)
	app._commit_interact()
	var item: StringName=app._region_offer.candidates[0].stable_id
	check(app._claim_modal_item(item),"actual first-map cache is claimed")
	app.wallet.grant(10,&"campaign_purchase_fixture")
	app.player.reset_at(first.merchant_position)
	await frames(2)
	check(app._region_purchase(),"first merchant accepts finite purchase")
	var first_shop:=app._region_shop_id()
	var first_chest_id: String=first.chests[0].id
	var first_hash: String=first.region_state.manifest_hash
	var build_before:=app.build.item_ids().duplicate()
	var coins_before:=app.wallet.balance
	var player_id:=app.player.get_instance_id()
	check(await load("res://tests/plains_campaign_fixture.gd").second_map(app,self),"mini victory confirmation enters second random whole map")
	var second:=app.stage as PlainsRegionStage
	var boss:=second.boss.get_node("Encounter") as WindkeeperEncounter
	check(second.generated.manifest.seed==PlainsRegionCampaign.seed_for(app.director.seed,2) and second.generated.manifest.manifest_hash!=first_hash,"second map has independently reproducible generation")
	check(second.generated.manifest.difficulty=="advanced" and boss.health.capacity==36 and (boss.definition as WindkeeperDefinition).storm_profile,"second map retains full three-phase region Boss")
	check(app.player.get_instance_id()==player_id and app.build.item_ids()==build_before and app.wallet.balance>=coins_before+12,"map transition keeps actor/build/coins and pays mini reward once")
	check(app.controller.actor_resources.health==health and app.controller.motor.tuning.max_jumps==1 and app.controller.motor.tuning.max_air_shots==2,"health identity and action resources survive transition")
	check(app.meta.snapshot().completed_biomes==0 and not app._gold_claimed,"mini Boss neither completes region nor awards gold/major ability")
	check(app._region_shop_id()!=first_shop and app.shop.quote(first_shop).stock==0 and app.shop.quote(app._region_shop_id()).stock==1,"map 2 merchant is a new bounded instance; old stock stays exhausted")
	check(second.chests[0].id!=first_chest_id and not second.chests[0].claimed,"map 2 cache does not reuse first-map reward-service IDs")
	check(app.region_states.size()==2 and app.region_states[1].claimed.has(first_chest_id),"first map ledger retained independently")
	check(second.map_view.visible_areas().all(func(a: Dictionary): return a.role not in ["boss","merchant","challenge_reward"]),"second map starts with its own local fog")
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"two-map manifest roundtrip includes mini transition")
	check(RunManifest.from_snapshot(app.director.manifest.snapshot())!=null,"native StringName item snapshot retains legitimate modifiers")
	var tuned_snapshot:Dictionary=JSON.parse_string(app.director.manifest.canonical_json())
	var corrupt_tuning:Dictionary=tuned_snapshot.duplicate(true)
	corrupt_tuning.stages[1].outputs.stage_tuning.ground_recoil_multiplier+=.13
	check(RunManifest.from_snapshot(corrupt_tuning)==null,"unearned stability tuning cannot pass region replay")
	var corrupt_items:Dictionary=tuned_snapshot.duplicate(true)
	corrupt_items.stages[1].outputs.capability_snapshot.items.append("unimplemented_item")
	check(RunManifest.from_snapshot(corrupt_items)==null,"unknown modifier provenance cannot pass replay")
	var malformed_capability:Dictionary=tuned_snapshot.duplicate(true)
	malformed_capability.stages[1].outputs.capability_snapshot="bad capability"
	check(RunManifest.from_snapshot(malformed_capability)==null,"malformed capability rejects without a script error")
	var hash_value: String=second.generated.manifest.manifest_hash
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(app.region_state.snapshot()))
	check(PlainsRegionState.new().restore(snapshot,hash_value),"exploration fog survives JSON snapshot")
	var corrupt: Dictionary=snapshot.duplicate(true)
	corrupt.explored["broken-cell"]=true
	check(not PlainsRegionState.new().restore(corrupt,hash_value),"malformed fog cells are rejected before rendering")
	var explored:=app.region_state.explored.duplicate(true)
	app._load_stage()
	await frames(8)
	check(app.region_state.explored==explored and app.wallet.balance>=coins_before+12,"reload keeps current map fog and mini reward, without paying again")
	check(not app.director.advance_region_map(app.lifetime.token(),&"wrong_second_advance").accepted(),"second map cannot generate a third Plains map")
	app.abandon_run()
	await frames(4)
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free()
	print("PLAINS CAMPAIGN MAP: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func corpus() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/verification/generated/plains_cohesion")
	var g:=PlainsRegionGenerator.new()
	var tuning:=PlayerTuning.load_default()
	var summary: Dictionary={"seeds":50,"maps":100,"fallbacks":0,"first":{},"second":{}}
	for index: int in [1,2]:
		var graphs: Dictionary={}; var travels: Dictionary={}; var families: Dictionary={}
		var enemy_counts: Array[int]=[];var behaviors: Dictionary={};var phrases: Dictionary={};var patterns: Dictionary={}
		var minimum_cycles:=100; var minimum_forks:=100; var advanced:=0
		for i: int in 50:
			var seed_value:=PlainsRegionCampaign.seed_for("two-map-corpus/%s" % i,index)
			var r:=g.generate(seed_value,tuning,false,"","intro" if index==1 else "advanced")
			check(r.ok,"actual campaign map seed generates")
			if not r.ok: continue
			var m: Dictionary=r.manifest
			enemy_counts.append(m.enemies.size())
			check(m.enemies.size()<=m.pressure.enemy_limit,"route pressure stays within fixed encounter budget")
			for e: Dictionary in m.enemies:
				behaviors[e.behavior_id]=true
				if e.has("pattern"):
					patterns[e.pattern]=true
					if e.pattern=="ferry_fan_crossfire":
						check(e.aerial and e.behavior_id=="fan_sentry" and PlainsEncounterPlanner.definition_for_behavior("fan_sentry").aerial,"ferry fan uses actual aerial three-way projectile behavior")
					elif e.pattern=="safe_cell_ambush":
						check(not e.aerial and e.behavior_id=="hopper" and e.patrol_radius==35 and PlainsEncounterPlanner.definition_for_behavior("hopper").behavior_id==&"hopper","thorn landing window uses real ground hopper and locked lunge")
					else: check(e.aerial and e.behavior_id=="diver" and e.dive_depth==115.0,"module window has actual aerial intercept behavior")
					check(m.nodes.any(func(n: Dictionary): return n.id==e.area),"movement pressure references a real assembled module")
					for n: Dictionary in m.nodes:
						if n.id!=e.area: continue
						var definition:=PlainsRegionGenerator.definition(n)
						var local:=Vector2(e.position[0]-n.offset[0],e.position[1]-n.offset[1])
						check(definition.world_bounds.encloses(Rect2(local-Vector2(55,25),Vector2(110,50))),"real patrol envelope stays inside its authored module bounds")
			for e: Dictionary in m.connections:
				if e.kind=="horizontal":
					var ids: Array=[]
					for n: int in e.modules: ids.append(m.nodes[n].module_id)
					check(not ids.is_empty(),"formal horizontal routes have actual local challenge content")
					phrases[JSON.stringify(ids)]=true
			if not m.fallback_id.is_empty(): summary.fallbacks+=1
			var forks: int=m.areas.filter(func(a: Dictionary): return g._degree(m,a.id)>=3).size()
			check(g._cycles(m)>=3 and forks>=3 and g._degree(m,m.prep_id)>=2 and m.fallback_id.is_empty(),"each randomized map has forks, cycles and multiple Boss approaches")
			minimum_cycles=mini(minimum_cycles,g._cycles(m)); minimum_forks=mini(minimum_forks,forks)
			var edges: Array=[]
			for e: Dictionary in m.connections:
				if e.condition=="open": edges.append([e.a,e.b])
			graphs[JSON.stringify(edges)]=true
			families[m.family]=true
			var trace=load("res://tests/plains_region_trace.gd").new()
			var assembler:=PlainsRegionAssembler.new(); assembler.manifest=m; trace.stage=assembler
			var path: Array=trace.path_to("area_0_1",str(m.prep_id))
			var itinerary: Array=[]
			for step: Dictionary in path: itinerary.append([step.edge.a,step.edge.b,step.forward])
			travels[JSON.stringify(itinerary)]=true
			assembler.free()
			for n: Dictionary in m.nodes:
				if n.module_id in ["plains_ferry_gears","plains_windchime_sequence"]: advanced+=1
			if i==0:
				var f:=FileAccess.open("res://build/verification/generated/plains_cohesion/map_%s.json" % index,FileAccess.WRITE)
				f.store_string(JSON.stringify(m,"  ",true))
		check(graphs.size()>=15 and travels.size()>=10 and families.size()==3,"both map numbers have actual random travel diversity across all families")
		check(patterns.size()>=3,"both maps generalize ferry, gear and bell-window enemy combinations")
		check(behaviors.size()==5 and enemy_counts.min()>=8,"both maps carry multiple actual movement-pressure enemy behaviors")
		if index==1: check(advanced==0,"first map excludes compound gear ferries and sequence-bell gates")
		else: check(advanced>=50,"second map actually uses advanced combinations")
		summary["first" if index==1 else "second"]={"graphs":graphs.size(),"early_boss_itineraries":travels.size(),"families":families.keys(),"minimum_cycles":minimum_cycles,"minimum_forks":minimum_forks,"advanced_modules":advanced,"enemies_min":enemy_counts.min(),"enemies_max":enemy_counts.max(),"enemies_average":float(enemy_counts.reduce(func(total: int,n: int): return total+n,0))/enemy_counts.size(),"behaviors":behaviors.keys(),"spatial_patterns":patterns.keys(),"connection_phrases":phrases.size()}
	var file:=FileAccess.open("res://build/verification/generated/plains_cohesion/corpus.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  ",true))
