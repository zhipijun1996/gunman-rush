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

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ITEM V5 ART FAILURE: "+label)

func resources_and_grammar() -> void:
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
	await committed_impacts()
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
