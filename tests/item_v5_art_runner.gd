extends SceneTree
## Real resources, actor/equipment, damage policy and presentation observers.
## Local target/resource setup is explicit fixture work, not natural playthrough.
const EQUIP := preload("res://tests/gear_inventory_support.gd")
const GOLDEN: Array[StringName] = [&"B01",&"B03",&"B11",&"P24",&"P14",&"G14",&"G16",&"N01"]
var checks := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var build: BuildState
var runtime: ItemRuntime
var life: DemoLifetime
var policy: FrameDamagePolicy
var stage: Node2D
var view: ItemEffectView
var impacts: Array[Dictionary] = []
var cue_events: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 ART FAILURE: "+label)

func resources_and_grammar() -> void:
	var shared_material := ItemArtLibrary.world_material()
	check(shared_material != null and shared_material.shader != null and shared_material.shader.resource_path == ItemArtLibrary.WORLD_SHADER_PATH,"world art uses dedicated atlas guard over established1wu/light-cap style")
	check(shared_material == ItemArtLibrary.world_material(),"world consumers share an actor-free material rather than perframe/peractor copies")
	var style_source := FileAccess.get_file_as_string(ItemArtLibrary.WORLD_STYLE_SHADER_PATH)
	var item_shader := FileAccess.get_file_as_string(ItemArtLibrary.WORLD_SHADER_PATH)
	var guard_begin := item_shader.find("\t// ITEM_ATLAS_GUARD_BEGIN\n")
	var guard_end_text := "\t// ITEM_ATLAS_GUARD_END\n"
	var guard_end := item_shader.find(guard_end_text)
	check(guard_begin>=0 and guard_end>guard_begin and item_shader.count("ITEM_ATLAS_GUARD_BEGIN") == 1 and item_shader.count("ITEM_ATLAS_GUARD_END") == 1,"item-specific shader extension has one finite atlas guard block")
	if guard_begin>=0 and guard_end>guard_begin:
		var normalized := item_shader.substr(0,guard_begin)+item_shader.substr(guard_end+guard_end_text.length())
		check(normalized == style_source,"removing only atlas guard gives byteexact canonical vertex/fragment/light style; future global style drift must be integrated deliberately")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ItemArtLibrary.CONFIG_PATH))
	check(ItemArtLibrary.validate_payload(payload).is_empty(),"actual item-art registry has valid data grammar")
	check(ItemArtLibrary.validate_sources(payload).is_empty() and ItemArtLibrary.reload_registry(),"actual PNGs and every registered region fit real source dimensions")
	var ids: Array[StringName] = GOLDEN.duplicate()
	if "--require-all-icons" in OS.get_cmdline_user_args():
		ids.clear()
		for item: ItemDefinition in ItemCatalogV5.all_items(): ids.append(item.stable_id)
		# The frozen workbook is a minimum identity set, not a ceiling on the
		# supported authoring additions. Every current addition enters this same
		# real-resource/unique-region audit below and must supply its own art.
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_v5_authoring_baseline.json"))
		var original_ids: Array = baseline.items.keys()
		check(original_ids.size() == 72,"full-art mode retains the original72 workbook identities")
		for original_id: String in original_ids:
			check(StringName(original_id) in ids,"full-art mode preserves original item "+original_id)
		common_resource_contract()
	var regions: Dictionary = {}
	for id: StringName in ids:
		var definition := ItemCatalogV5.get_item(id)
		check(definition != null,"art consumer resolves actual definition "+String(id))
		if definition == null: continue
		check(String(definition.icon_key).begins_with("item_"),"dedicated icon key declared in current item metadata "+String(id))
		check(ItemArtLibrary.has_icon(definition.icon_key),"every audited current definition has a registered dedicated icon "+String(id))
		var texture := ItemPresentation.icon(definition.icon_key) as AtlasTexture
		check(texture != null and texture.atlas != null and texture.filter_clip,"actual common UI icon path resolves safe atlas resource "+String(id))
		if texture == null: continue
		var identity := str(texture.atlas.resource_path)+"/"+str(texture.region)
		check(not regions.has(identity),"each item uses its own source region rather than renamed duplicate "+String(id))
		regions[identity] = true
		var pixels := texture.get_image()
		check(pixels != null and not pixels.is_empty() and pixels.get_width()>0 and pixels.get_height()>0,"real icon pixels are readable "+String(id))
		if pixels != null and not pixels.is_empty():
			check(pixels.get_pixel(0,0).a == 0 and pixels.get_pixel(pixels.get_width()-1,pixels.get_height()-1).a == 0,"actual icon region has transparent corner padding "+String(id))
	for mapping: Array in [[&"flywheel",&"P24"],[&"small_drone",&"P14"],[&"pulse",&"G16"]]:
		var clip := ItemArtLibrary.entity_clip(mapping[0],mapping[1])
		check(not clip.is_empty() and ItemArtLibrary.has_clip(clip),"golden entity uses a real authored body clip "+String(mapping[0]))
		check(ItemArtLibrary.frame_texture(clip,0) != null and ItemArtLibrary.clip_duration(clip)>0,"actual entity frame and animation duration resolve "+String(mapping[0]))
		var middle := ItemArtLibrary.frame_texture(clip,ItemArtLibrary.clip_duration(clip)*.5)
		if middle != null:
			var image := middle.get_image()
			check(image != null and image.get_used_rect().has_area(),"authored entity has real visible pixels rather than an empty region "+String(mapping[0]))
			if image != null and mapping[0] == &"small_drone" and payload.clips.has(String(clip)):
				var declaration: Dictionary = payload.clips[String(clip)]
				var occupied := image.get_used_rect()
				var projected := Vector2(occupied.size)*Vector2(float(declaration.world_size[0]),float(declaration.world_size[1]))/Vector2(image.get_size())
				check(projected.x<=37.0001 and projected.y<=24.0001,"actual sampled patrol body/wings stay within the frozen37x24wu envelope")
	check(not ItemArtLibrary.entity_clip(&"flywheel_trail",&"P24").is_empty(),"returning flywheel has its own authored trail on the actual motion path")
	for id: StringName in [&"P24",&"P14",&"G16"]:
		check(not ItemArtLibrary.cue_clip(&"item_committed_impact",id).is_empty(),"dedicated committed receiver clip registered "+String(id))
	check(ItemArtLibrary.cue_source(&"item_clock_pulse",&"") == &"G16","unique clock cast source is configured rather than guessed in renderer")
	check(not ItemArtLibrary.cue_clip(&"item_drone_fire",&"P14").is_empty(),"patrol muzzle is a fire recipe separate from receiver impact")
	var empty := {"schema_version":1,"icons":{},"clips":{},"entities":{},"cues":{}}
	check(ItemArtLibrary.validate_payload(empty).is_empty(),"empty staging registry remains explicitly incomplete rather than executable data")
	for value: Variant in [true,0,2,"1",1.5]:
		var bad := empty.duplicate(true)
		bad.schema_version = value
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"invalid art schema rejected: "+str(value))
	var minimal := {"texture":"res://assets/items/v5/test.png","regions":[[0,0,16,16]],"fps":24,"loop":false,"world_size":[16,16],"pivot":[.5,.5]}
	for field: String in ["fps","regions","world_size","pivot","loop"]:
		var bad := empty.duplicate(true)
		var row := minimal.duplicate(true)
		row.erase(field)
		bad.clips = {"test":row}
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"missing clip field fails closed: "+field)
	for value: Variant in [0,-1,NAN,INF,"24"]:
		var bad := empty.duplicate(true)
		var row := minimal.duplicate(true)
		row.fps = value
		bad.clips = {"test":row}
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"invalid clip speed rejected: "+str(value))
	for path: String in ["res://scripts/player/player_controller.gd","https://example.com/test.png","res://assets/items/v5/../other.png"]:
		var bad := empty.duplicate(true)
		bad.icons = {"item_bad":{"texture":path,"region":[0,0,16,16]}}
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"art data cannot load scripts, network paths or escaped files: "+path)
	var out_of_bounds := payload.duplicate(true)
	if not out_of_bounds.icons.is_empty():
		var key: String = out_of_bounds.icons.keys()[0]
		out_of_bounds.icons[key].region = [100000,100000,16,16]
		check(not ItemArtLibrary.validate_sources(out_of_bounds).is_empty(),"actual image bounds reject an otherwise valid atlas rectangle")
	check(ItemArtLibrary.icon_texture(&"item_missing_negative_fixture") == null,"explicit missing art key has a diagnostic/null result, never a generic item image")
	check(not String(ItemArtLibrary.diagnostics().last_error).is_empty(),"missing explicit icon leaves an observable diagnosis")
	var memory := ItemArtLibrary.diagnostics()
	check(int(memory.registered_texture_rgba_upper_bound_bytes)>0 and int(memory.registered_texture_rgba_upper_bound_bytes)<=64*1024*1024,"actual unique registered source textures fit the frozen64MiB RGBA upper-bound budget")

func fresh() -> void:
	paused = false
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.get("world")): (fixture.get("world") as Node).free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.set("tree",self)
	await fixture.call("fixture",Vector2(80,20))
	actor = fixture.get("controller") as PlayerController
	life = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor,life,&"item_art_fixture")
	runtime = ItemRuntime.new()
	runtime.configure(actor,build,life,RunWallet.new())
	stage = Node2D.new()
	(fixture.get("world") as Node).add_child(stage)
	runtime.bind_world(stage,&"item_art/map_one")
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	(fixture.get("world") as Node).add_child(policy)
	policy.set_physics_process(false)
	policy.register_player_controller(actor)
	check(policy.register_target(&"player",actor.actor_resources.health,true),"real damage policy registers the player")
	runtime.effect_cued.connect(_observe)
	view = ItemEffectView.new()
	stage.add_child(view)
	check(view.configure(runtime),"actual presentation observer subscribes to the real runtime")
	impacts.clear()
	check(EQUIP.add_and_equip(build,&"art/flywheel",ItemCatalogV5.get_item(&"P24")),"actual paused equipment transaction owns and equips impact source")
	runtime.sync()

func _observe(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	cue_events.append({"kind":kind,"point":point,"detail":detail.duplicate(true)})
	if kind == &"item_committed_impact": impacts.append({"point":point,"detail":detail.duplicate(true)})

func enemy(id: StringName, hp := 10.0) -> Dictionary:
	var body: StaticBody2D = fixture.call("body",Rect2(Vector2(150,0),Vector2(20,40)),&"enemy")
	body.collision_layer = 2
	var receiver := body.get_node("Damageable") as Damageable
	receiver.actor_id = body.get_instance_id()
	var definition := HealthDefinition.new()
	definition.resource_id = id
	definition.max_health = hp
	definition.initial_current = hp
	var health := HealthState.new()
	check(health.configure(definition),"real target health fixture configured "+String(id))
	receiver.bind_health(health)
	check(policy.bind_damageable(id,receiver,health),"target bound to real frame policy "+String(id))
	return {"body":body,"receiver":receiver,"health":health}

func committed_impacts() -> void:
	await fresh()
	var target := enemy(&"ordinary")
	check(runtime.deal(target.receiver,1.0,&"queued",&"P24"),"actual source submits authenticated damage")
	check(impacts.is_empty() and view.snapshot().count == 0,"submission alone never creates a receiver impact")
	policy.resolve_batch()
	check(target.health.current == 9 and impacts.size() == 1,"one actual positive HP commit emits exactly one presentation receipt")
	check(impacts.size() == 1 and impacts[0].detail.definition_id == &"P24" and not impacts[0].detail.has("amount") and not impacts[0].detail.has("hp_lost"),"receipt preserves source and does not mislabel requested amount as actual lost HP")
	check(view.snapshot().count == 1,"actual observer turns committed receipt into its dedicated clip")
	if impacts.size()!=1 or int(view.snapshot().count)!=1: return
	var first: Dictionary = impacts[0]
	runtime.cue(&"item_committed_impact",first.point,first.detail)
	check(view.snapshot().count == 1,"duplicate delivery of the real receipt cannot duplicate receiver art")
	paused = true
	view.advance_visual(.2)
	check(is_zero_approx(float(view.snapshot().entries[0].age)),"paused game keeps artist clip age frozen")
	paused = false
	view.advance_visual(.02)
	check(is_equal_approx(float(view.snapshot().entries[0].age),.02),"artist clip resumes from original world activity time")
	var none: Array[StringName] = []
	check(EQUIP.equip_ids(build,none),"real source unload commits atomically")
	runtime.sync()
	view.advance_visual(0)
	check(view.snapshot().count == 0,"unload retracts in-flight dedicated art without advancing its animation")
	var restored: Array[StringName] = [build.inventory.instance_for_definition(&"P24").instance_id]
	check(EQUIP.equip_ids(build,restored),"real same-instance re-equip creates a new equipment revision")
	runtime.sync()
	view.clear()
	runtime.cue(&"item_committed_impact",first.point,first.detail)
	check(view.snapshot().count == 0,"old legitimate receipt cannot become a fresh clip after re-equip and cleared view deduplication")
	view.queue_free()
	view = ItemEffectView.new()
	stage.add_child(view)
	check(view.configure(runtime),"new stage observer connects without inheriting an old dedup cache")
	runtime.cue(&"item_committed_impact",first.point,first.detail)
	check(view.snapshot().count == 0,"new observer also rejects the stale carried source identity")
	impacts.clear()
	check(runtime.deal(target.receiver,1.0,&"fresh_identity",&"P24"),"newly equipped source can submit an independent current hit")
	policy.resolve_batch()
	check(impacts.size()==1 and int(view.snapshot().count)==1,"new current positive receipt is still displayed after stale receipt refusals")
	if impacts.size()!=1: return
	var current: Dictionary = impacts[0]
	for field: String in ["session","run_epoch","stage_epoch","actor_epoch","weapon_epoch","equipment_revision","world_id"]:
		var changed: Dictionary = current.detail.duplicate(true)
		changed[field] = int(changed[field])+1
		view.clear()
		runtime.cue(&"item_committed_impact",current.point,changed)
		check(view.snapshot().count == 0,"carried identity is checked rather than stamped on delivery: "+field)
	var other_map: Dictionary = current.detail.duplicate(true)
	other_map.map_key = &"item_art/old_map"
	view.clear()
	runtime.cue(&"item_committed_impact",current.point,other_map)
	check(view.snapshot().count == 0,"carried map identity cannot cross a scene delivery")
	var coerced: Dictionary = current.detail.duplicate(true)
	coerced.equipment_revision = float(coerced.equipment_revision)
	view.clear()
	runtime.cue(&"item_committed_impact",current.point,coerced)
	check(view.snapshot().count == 0,"non-live numeric coercion is not accepted as a live integer receipt")
	life.invalidate_actor()
	check(runtime.is_live(),"explicit actor-epoch lifecycle fixture keeps current player/source live")
	view.clear()
	runtime.cue(&"item_committed_impact",current.point,current.detail)
	check(view.snapshot().count == 0,"actual actor epoch change refuses the previous legitimate receipt")
	var previous_view := view
	var next_world := Node2D.new()
	(fixture.get("world") as Node).add_child(next_world)
	runtime.bind_world(next_world,&"item_art/map_one")
	check(runtime.is_live(),"controlled same-key world rebind keeps the current source live")
	view = ItemEffectView.new()
	next_world.add_child(view)
	check(view.configure(runtime),"new-world observer explicitly binds the new world owner")
	impacts.clear()
	check(runtime.deal(target.receiver,1.0,&"new_world",&"P24"),"actual new world submits a new independent hit")
	policy.resolve_batch()
	check(impacts.size()==1 and int(view.snapshot().count)==1,"new-world committed receipt reaches its current observer")
	check(previous_view.snapshot().count == 0,"old observer cannot paint new-world receipts even while its old node remains alive")

	await fresh()
	target = enemy(&"dies_before_commit")
	check(runtime.deal(target.receiver,1.0,&"dead_before",&"P24"),"accepted queue fixture precedes another target death")
	target.health.apply_damage(ActorResourceRequest.new(&"fixture/death_before_batch",target.health.epoch,10,target.health.get_instance_id()))
	policy.resolve_batch()
	check(impacts.is_empty(),"target dying before queued request commits produces no fake reception")

	await fresh()
	target = enemy(&"lethal_clip",.5)
	check(runtime.deal(target.receiver,9.0,&"lethal",&"P24"),"real lethal target fixture accepts request exceeding remaining HP")
	policy.resolve_batch()
	check(target.health.terminal and impacts.size() == 1,"positive lethal HP commit can show impact after receiver becomes inactive")

	await fresh()
	target = enemy(&"removed_before")
	check(runtime.deal(target.receiver,1.0,&"revoked",&"P24"),"real pending source receipt admitted before unload")
	check(EQUIP.equip_ids(build,none),"source unloaded before original batch resolves")
	policy.resolve_batch()
	check(target.health.current == 10 and impacts.is_empty(),"revoked damage source neither changes HP nor emits a dedicated impact")

	await fresh()
	target = enemy(&"callback_removes")
	check(runtime.deal(target.receiver,1.0,&"callback_revoked",&"P24",_unload_callback),"real commit fixture installs a callback that removes its source")
	policy.resolve_batch()
	check(target.health.current == 9 and build.equipment.equipped_ids().is_empty() and impacts.is_empty(),"earlier commit callback may remove equipment: accepted damage remains, stale visual is suppressed")

func _unload_callback() -> void:
	var none: Array[StringName] = []
	check(EQUIP.equip_ids(build,none),"setup callback uses original paused equipment transaction")

func run() -> void:
	resources_and_grammar()
	recipe_geometry_cases()
	await committed_impacts()
	await actual_resource_and_mark_hooks()
	await rescue_commit_bridge()
	await publication_receipt_epochs()
	if runtime != null: runtime.clear()
	if fixture != null and is_instance_valid(fixture.get("world")): (fixture.get("world") as Node).free()
	view = null
	stage = null
	actor = null
	policy = null
	build = null
	runtime = null
	fixture = null
	life = null
	ItemArtLibrary.clear_cache()
	await process_frame
	print("ITEM V5 ART: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)


func recipe_geometry_cases() -> void:
	var basic := {"texture":"res://assets/items/v5/test.png","regions":[[0,0,16,16]],"fps":24,"loop":false,"world_size":[20,4],"pivot":[.5,.5]}
	var payload := {"schema_version":1,"icons":{},"clips":{"e0":basic.duplicate(true),"e1":basic.duplicate(true),"e2":basic.duplicate(true)},"entities":{},"cues":{}}
	var point := Vector2(10,20)
	var legacy := ItemArtLibrary.resolve_clip_pose(basic,point,Vector2.UP,Vector2.LEFT,NAN,point,1.25)
	check(not legacy.is_empty() and legacy.position == point and legacy.size_multiplier == Vector2.ONE and legacy.angle == 1.25,"omitted optional recipe preserves the exact old angle/position/canvas")
	for facing: String in ["fixed","aim","travel"]:
		var row := basic.duplicate(true)
		row.orientation = facing
		var pose := ItemArtLibrary.resolve_clip_pose(row,point,Vector2.UP,Vector2.LEFT,NAN,point,1.25)
		var expected := 0.0 if facing == "fixed" else Vector2.UP.angle() if facing == "aim" else Vector2.LEFT.angle()
		check(not pose.is_empty() and is_equal_approx(float(pose.angle),expected),"recipe reads only actual declared orientation "+facing)
	var radial := basic.duplicate(true)
	radial.geometry = "radius"
	radial.reference_radius = 10
	var result := ItemArtLibrary.resolve_clip_pose(radial,point,Vector2.RIGHT,Vector2.ZERO,30,point)
	check(not result.is_empty() and result.size_multiplier == Vector2.ONE*3 and result.position == point,"radius geometry scales solely from actual radius/reference")
	for radius: float in [NAN,INF,0,-1,321]:
		check(ItemArtLibrary.resolve_clip_pose(radial,point,Vector2.RIGHT,Vector2.ZERO,radius,point).is_empty(),"invalid or unobserved radius fails closed "+str(radius))
	var segment := basic.duplicate(true)
	segment.geometry = "segment"
	result = ItemArtLibrary.resolve_clip_pose(segment,point,Vector2.UP,Vector2.ZERO,NAN,Vector2(110,20))
	check(not result.is_empty() and result.position == Vector2(60,20) and result.size_multiplier == Vector2(5,1) and is_zero_approx(float(result.angle)),"actual segment endpoints determine center/length while thickness stays fixed")
	segment.pivot = [0,.5]
	result = ItemArtLibrary.resolve_clip_pose(segment,point,Vector2.UP,Vector2.ZERO,NAN,Vector2(10,120))
	check(not result.is_empty() and result.position == point and result.size_multiplier == Vector2(5,1) and is_equal_approx(float(result.angle),PI*.5),"declared segment pivot aligns source start exactly with real vertical endpoint")
	for finish: Vector2 in [point,Vector2(INF,20),Vector2(1291,20)]:
		check(ItemArtLibrary.resolve_clip_pose(segment,point,Vector2.RIGHT,Vector2.ZERO,NAN,finish).is_empty(),"zero/nonfinite/oversized segment is refused "+str(finish))
	payload.entities = {"growth_drone":{"G19":{"variants":{"0":"e0","1":"e1","2":"e2"}}}}
	check(ItemArtLibrary.validate_payload(payload).is_empty(),"bounded declarative evolution map admits exactly three authored states")
	for state: int in 3:
		check(ItemArtLibrary._mapped_clip(payload.entities.growth_drone,&"G19",state) == StringName("e"+str(state)),"evolution selector reads actual state without writing progress "+str(state))
	for state: int in [-1,3]:
		check(ItemArtLibrary._mapped_clip(payload.entities.growth_drone,&"G19",state).is_empty(),"invalid explicit evolution is diagnosed instead of silently selecting generic state "+str(state))
	for states: Dictionary in [{"0":"e0","1":"e1"},{"0":"e0","1":"e1","2":"missing"},{"0":"e0","1":"e1","2":"e2","3":"e2"}]:
		var bad := payload.duplicate(true)
		bad.entities.growth_drone.G19.variants = states
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"incomplete/unknown/unbounded evolution map rejected "+str(states))
	for field: String in ["orientation","geometry","timing"]:
		for invalid: Variant in [false,1,{},"unsupported"]:
			var bad := payload.duplicate(true)
			bad.clips.e0[field] = invalid
			check(not ItemArtLibrary.validate_payload(bad).is_empty(),"optional pose metadata has strict finite enums "+field+"/"+str(invalid))
	for reference: Variant in [0,-1,NAN,INF,true,"10",641]:
		var bad := payload.duplicate(true)
		bad.clips.e0.geometry = "radius"
		bad.clips.e0.reference_radius = reference
		check(not ItemArtLibrary.validate_payload(bad).is_empty(),"radius recipe requires a finite bounded numeric reference "+str(reference))
	for clip: StringName in [&"p24.rotor",&"p24.trail",&"p14.body",&"p14.muzzle",&"g16.cast",&"g16.wave",&"g16.impact"]:
		result = ItemArtLibrary.clip_pose(clip,point,Vector2.UP,Vector2.LEFT,30,Vector2(110,20),1.25)
		check(not result.is_empty() and result.position == point and result.size_multiplier == Vector2.ONE and result.angle == 1.25 and not ItemArtLibrary.clip_uses_event_timing(clip),"first golden clip retains original geometry and clock "+String(clip))

func source_fixture(ids: Array[StringName]) -> void:
	var empty: Array[StringName] = []
	check(EQUIP.equip_ids(build,empty),"actual fixture clears prior golden source through equipment transaction")
	for id: StringName in ids:
		check(EQUIP.add_and_equip(build,StringName("art/current/"+String(id)),ItemCatalogV5.get_item(id)),"actual fixture owns and equips "+String(id))
	runtime.sync()
	view.clear()
	cue_events.clear()
	impacts.clear()

func events_of(kind: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in cue_events:
		if row.kind == kind: rows.append(row)
	return rows

func actual_resource_and_mark_hooks() -> void:
	await fresh()
	source_fixture([&"B13",&"P27"])
	var granted := runtime.barrier_grant(100,&"B13/art/positive")
	check(granted>0 and events_of(&"barrier").size() == 1 and events_of(&"barrier")[0].detail.amount == granted,"barrier art follows actual positive accepted count rather than requested100")
	check(runtime.barrier_grant(100,&"B13/art/positive") == 0 and events_of(&"barrier").size() == 1,"barrier receipt replay creates neither new barrier nor art")
	check(runtime.barrier_grant(1,&"B13/art/full") == 0 and events_of(&"barrier").size() == 1,"full shared barrier capacity never fabricates positive grant art")
	var health := actor.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"art/fixture/hurt",health.epoch,1,health.get_instance_id()))
	check(runtime.heal(100,&"P27/art/heal",&"P27") and events_of(&"heal").size() == 1 and is_equal_approx(float(events_of(&"heal")[0].detail.amount),1),"heal art follows actual positive clipped HPgrant")
	check(not runtime.heal(100,&"P27/art/heal",&"P27") and events_of(&"heal").size() == 1,"healing receipt replay never duplicates art")
	check(not runtime.heal(1,&"P27/art/full",&"P27") and events_of(&"heal").size() == 1,"full HP never emits positive heal art")
	health.apply_damage(ActorResourceRequest.new(&"art/fixture/hurt_again",health.epoch,1,health.get_instance_id()))
	health.normal_healing_blocked = true
	check(not runtime.heal(1,&"P27/art/blocked",&"P27") and events_of(&"heal").size() == 1,"original blocked-healing authority also refuses art")
	health.normal_healing_blocked = false
	cue_events.clear()
	health.changed.connect(func(_result: ActorResourceResult) -> void:
		var empty: Array[StringName] = []
		check(EQUIP.equip_ids(build,empty),"acceptedHP callback may really unload source before presentation"),CONNECT_ONE_SHOT)
	check(runtime.heal(1,&"P27/art/unload_after_commit",&"P27") and events_of(&"heal").is_empty(),"positive HPcommit survives while changed-source visual is suppressed")
	await fresh()
	source_fixture([&"G01"])
	var target := enemy(&"arm_fixture")
	var event := {"session":actor.session_id,"packet":101,"shot":101,"airborne":true,"skill":false,"receiver":target.receiver,"point":target.body.global_position,"direction":Vector2.RIGHT}
	runtime.on_hit(event)
	check(events_of(&"item_echo_armed").size() == 1 and events_of(&"echo").is_empty() and impacts.is_empty(),"actual G01mark assignment emits arm only, never request/detonation/HPimpact")
	var mark := runtime.presentation_mark(&"G01",target.receiver)
	check(not mark.is_empty() and mark.receipt == events_of(&"item_echo_armed")[0].detail.mark_receipt,"arm observer reads exact actual mark receipt")
	runtime.on_hit(event)
	check(events_of(&"item_echo_armed").size() == 1,"same actual packet cannot duplicate an armed mark")
	target.body.position += Vector2(10,0)
	check(runtime.presentation_mark(&"G01",target.receiver).point == target.body.global_position,"read-only mark projection follows actual target motion")
	event.packet = 102
	event.shot = 102
	runtime.on_hit(event)
	check(runtime.presentation_mark(&"G01",target.receiver).is_empty() and events_of(&"item_echo_armed").size() == 1 and events_of(&"echo").size() == 1 and impacts.is_empty(),"differentpacket consumes actualmark; earlier echo remains a damage request rather than arm/impact")
	policy.resolve_batch()
	check(target.health.current<10 and impacts.size() == 1 and impacts[0].detail.definition_id == &"G01","only positive committed detonation gets dedicated G01receiver receipt")
	await fresh()
	source_fixture([&"B24"])
	target = enemy(&"dot_fixture")
	runtime.on_hit({"session":actor.session_id,"packet":201,"shot":201,"airborne":false,"skill":false,"receiver":target.receiver,"point":target.body.global_position,"direction":Vector2.RIGHT})
	runtime.advance(.25,.25)
	check(impacts.is_empty(),"DOT advance/queued damage never fabricates receiver tick art")
	policy.resolve_batch()
	check(target.health.current<10 and impacts.size() == 1 and impacts[0].detail.definition_id == &"B24","existing actual positive HPcommit already supplies exact DOT source with no new damage hook")


func common_resource_contract() -> void:
	var entity_bindings: Array = [["large_drone","G05","g05.large_guard"],["temporary_drone","P15","p15.temporary_drone"],["throw","G14","g14.urn_flight"],["trap","P25","p25.needle_trap"],["crystal","P20","p20.crystal"],["orbit_guard","P16","p16.orbit_guard"]]
	for binding: Array in entity_bindings:
		check(ItemArtLibrary.entity_clip(StringName(binding[0]),StringName(binding[1])) == StringName(binding[2]),"actual common entity mapping consumes authored resource "+str(binding))
	var cue_bindings: Array = [["item_blast","B33","b33.touch_blast"],["item_throw_burst","G14","g14.urn_burst"],["item_blast","P25","p25.needle_burst"],["ring","B23","b23.tail_ring"],["item_committed_impact","P34","p34.third_round_shock"],["item_committed_impact","P09","p09.relay_blast"],["item_motion_path","P12","p12.motion_blade"],["mark","P13","p13.eye_mark"],["mark","B19","b19.dream_mark"],["item_echo_armed","G01","g01.echo_seed"],["item_committed_impact","G01","g01.echo_detonation"],["arc","P29","p29.wire_lightning"],["arc","G06","g06.crown_lightning"],["cloud","P10","p10.corrosion"],["item_committed_impact","B24","b24.ember_tick"],["barrier","B13","shared.barrier"],["barrier","B32","shared.barrier"],["barrier","G02","shared.barrier"],["barrier","N02","shared.barrier"],["item_guard_active","P26","p26.echo_guard"],["heal","P27","shared.heal"],["heal","G03","shared.heal"],["item_rescue_committed","G04","g04.rescue"],["time_refund","B06","b06.time_refund"],["item_break_bell_committed","B14","s15.break_bell"],["coin","B16","shared.coin_gain"],["coin","B20","shared.coin_gain"],["coin","G10","shared.coin_gain"],["skill_credit_ready","G07","s10.skill_credit"]]
	for binding: Array in cue_bindings:
		check(ItemArtLibrary.cue_clip(StringName(binding[0]),StringName(binding[1])) == StringName(binding[2]),"actual common cue mapping consumes its real item source "+str(binding))
		check(ItemArtLibrary.clip_uses_event_timing(StringName(binding[2])),"new single-frame cue retains actual original event clock "+String(binding[2]))
	var keys: Array[StringName] = [&"g05.large_guard",&"p15.temporary_drone",&"g19.body.0",&"g19.body.1",&"g19.body.2",&"g14.urn_flight",&"p25.needle_trap",&"p20.crystal",&"p16.orbit_guard",&"b33.touch_blast",&"g14.urn_burst",&"p25.needle_burst",&"b23.tail_ring",&"p34.third_round_shock",&"p09.relay_blast",&"p12.motion_blade",&"p13.eye_mark",&"b19.dream_mark",&"g01.echo_seed",&"g01.echo_detonation",&"p29.wire_lightning",&"g06.crown_lightning",&"p10.corrosion",&"b24.ember_tick",&"shared.barrier",&"p26.echo_guard",&"shared.heal",&"g04.rescue",&"b06.time_refund",&"s15.break_bell",&"shared.coin_gain",&"s10.skill_credit"]
	for key: StringName in keys:
		check(ItemArtLibrary.has_clip(key) and ItemArtLibrary.frame_texture(key,0) != null,"full-art mode requires actual static semantic resource "+String(key))
	for state: int in 3:
		check(ItemArtLibrary.entity_clip(&"growth_drone",&"G19",state) == StringName("g19.body."+str(state)),"full-art evolution selects its own actual authored state "+str(state))
	check(ItemArtLibrary.cue_clip(&"echo",&"G01").is_empty() and ItemArtLibrary.cue_clip(&"item_echo_armed",&"G01") == &"g01.echo_seed" and ItemArtLibrary.cue_clip(&"item_committed_impact",&"G01") == &"g01.echo_detonation","G01arm and committed detonation stay distinct from earlier echo request")
	check(ItemArtLibrary.cue_clip(&"skill_credit_ready",&"G07") == &"s10.skill_credit" and ItemArtLibrary.cue_clip(&"skill_credit_ready",&"S10").is_empty(),"S10synergy artwork observes actual item sourceG07")
	check(ItemArtLibrary.cue_source(&"time_refund",&"") == &"B06" and ItemArtLibrary.cue_clip(&"time_refund",&"B06") == &"b06.time_refund","the unique amount-only refund explicitly names actual sourceB06 in data")


func rescue_request(id: StringName) -> DamageRequest:
	var request := DamageRequest.new()
	request.token = life.token()
	request.event_id = id
	request.source_id = &"art_enemy_fixture"
	request.target_id = &"player"
	request.health_epoch = actor.actor_resources.health.epoch
	request.actor_epoch = life.actor_epoch
	request.kind = DamageRequest.Kind.MONSTER
	request.amount = 1.0
	return request

func rescue_commit_bridge() -> void:
	await fresh()
	source_fixture([&"G04"])
	actor.combat_energy.grant("art/rescue/funding",100)
	check(actor.combat_energy.current>=float(runtime.effect(&"G04").combat_energy_cost),"actual original resource grant funds rescue fixture before lethal request")
	var health := actor.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"art/one_hp",health.epoch,health.current-1,health.get_instance_id()))
	check(policy.submit(rescue_request(&"art/zero_hp_delta_rescue")) and events_of(&"item_rescue_committed").is_empty(),"queued lethal request alone creates no rescue art")
	var results := policy.resolve_batch()
	check(results.size() == 1 and results[0].rescued and is_zero_approx(results[0].hp_lost) and health.current == 1,"actual original policy commits a valid zeroHPdelta rescue")
	check(events_of(&"item_rescue_committed").size() == 1 and events_of(&"item_rescue_committed")[0].detail.definition_id == &"G04","existing batch_resolved bridge emits actual rescue art even with zeroHPdelta")
	policy.batch_resolved.emit(results)
	check(events_of(&"item_rescue_committed").size() == 1,"replayed real batch has no remaining presentation ticket")
	await fresh()
	source_fixture([&"G04"])
	actor.combat_energy.grant("art/rescue/funding",100)
	check(actor.combat_energy.current>=float(runtime.effect(&"G04").combat_energy_cost),"actual original resource grant funds rescue fixture before lethal request")
	health = actor.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"art/one_hp_again",health.epoch,health.current-1,health.get_instance_id()))
	# Subscribe before defense prepares its observer. A real earlier listener can
	# revoke source ownership after HPresolution but before presentation delivery.
	policy.batch_resolved.connect(func(_results: Array[DamageResult]) -> void:
		var empty: Array[StringName] = []
		check(EQUIP.equip_ids(build,empty),"earlier batch callback actually unloads rescue source"),CONNECT_ONE_SHOT)
	check(policy.submit(rescue_request(&"art/revoked_rescue")),"actual rescue request admitted for source-change counterexample")
	results = policy.resolve_batch()
	check(results.size() == 1 and results[0].rescued and is_zero_approx(results[0].hp_lost) and health.current == 1 and events_of(&"item_rescue_committed").is_empty(),"already-committed rescue remains valid while stale source art is suppressed")
	check(EQUIP.equip_ids(build,[build.inventory.instance_for_definition(&"G04").instance_id]),"same rescue instance can be legitimately re-equipped")
	runtime.sync()
	policy.batch_resolved.emit(results)
	check(events_of(&"item_rescue_committed").is_empty(),"re-equipping and oldbatch replay cannot revive a cleared rescue ticket")
	await fresh()
	source_fixture([&"G04"])
	actor.combat_energy.grant("art/rescue/funding",100)
	check(actor.combat_energy.current>=float(runtime.effect(&"G04").combat_energy_cost),"actual original resource grant funds rescue fixture before lethal request")
	health = actor.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"art/prepare_only_hp",health.epoch,health.current-1,health.get_instance_id()))
	var prepared := runtime.defend_request(rescue_request(&"art/prepare_only"),health.current)
	check(bool(prepared.rescued) and events_of(&"item_rescue_committed").is_empty(),"defense preparation/spend/state alone is explicitly not committed rescue art")
	policy.resolve_batch()
	check(events_of(&"item_rescue_committed").is_empty(),"empty real batch cannot commit an unmatched prepared rescue ticket")


func publication_receipt_epochs() -> void:
	await fresh()
	source_fixture([&"P14"])
	var point := actor.motor.global_position
	var details := {"definition_id":&"P14","end":point+Vector2(10,0)}
	runtime.cue(&"item_drone_fire",point,details)
	var published: Dictionary = events_of(&"item_drone_fire")[0]
	check(published.detail.has("event_id") and published.detail.has("equipment_revision") and view.snapshot().count == 1,"original muzzle cue receives source-publication identity and still renders once")
	var empty: Array[StringName] = []
	check(EQUIP.equip_ids(build,empty),"actual equipment unload invalidates published generic cue")
	var owned: Array[StringName] = [build.inventory.instance_for_definition(&"P14").instance_id]
	check(EQUIP.equip_ids(build,owned),"actual same-instance reload obtains a new generic-cue source revision")
	runtime.sync()
	view.clear()
	runtime.cue(&"item_drone_fire",published.point,published.detail)
	check(view.snapshot().count == 0 and events_of(&"item_drone_fire")[1].detail == published.detail,"carried old generic identity is neither refreshed nor rendered after source reload")
	runtime.cue(&"item_drone_fire",point,details)
	check(view.snapshot().count == 1,"fresh synchronous generic cue remains usable after reload")
	view.clear()
	runtime.cue(&"item_drone_fire",point,{"definition_id":&"P14","end":point+Vector2(10,0),"session":actor.session_id})
	check(view.snapshot().count == 0,"partial carried identity cannot be blessed by filling missing current fields")
	for kind: StringName in [&"item_committed_impact",&"barrier",&"heal",&"item_guard_active",&"item_rescue_committed",&"item_break_bell_committed"]:
		runtime.cue(kind,point,{"definition_id":&"P14","event_id":StringName("fake/"+String(kind))})
		check(not events_of(kind).back().detail.has("session"),"publication cannot mint a missing actual commit proof for "+String(kind))
