extends SceneTree
## Actual world/Definition/App configuration and placement counterexamples.
## This does not claim live traversal, enemy-phase fairness or player approval.
const WORLD := preload("res://scripts/generation/forest_exploration_world.gd")
const ECOLOGY := preload("res://scripts/generation/forest_exploration_ecology.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var output := "res://build/region_bible_v2/forest-exploration-ecology"
var borrow_pod_only := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
		if arg=="--borrow-pod-only": borrow_pod_only=true
	run.call_deferred()

func check(value: bool,label: String) -> void:
	assertions += 1
	if not value: failures += 1; push_error(label)

func run() -> void:
	if borrow_pod_only:
		await borrow_pod_run()
		return
	var kinds: Dictionary = {}
	var sample: Dictionary = {}
	var crossbranch_sample: Dictionary = {}
	for seed_index: int in 4:
		for map_index: int in [1,2]:
			var m := WORLD.build("forest-ecology-feedback-%s" % seed_index,map_index)
			var geometry_before := geometry(m)
			ECOLOGY.install(m)
			check(geometry(m)==geometry_before,"ecology does not alter actual geometry, fruit, routes or rewards")
			check(not m.enemies.is_empty() and m.enemies.size()<=ECOLOGY.MAXIMUM_ACTORS,"bounded actual ecology is present")
			check(m.exploration_ecology.native_interactions=="unverified","placement never signs live enemy interactions")
			var original := JSON.stringify([m.enemies,m.enemy_drops,m.exploration_ecology])
			ECOLOGY.install(m)
			check(JSON.stringify([m.enemies,m.enemy_drops,m.exploration_ecology])==original,"same seed/idempotent install retains source rows and actual drop settlement")
			check(m.streams.exploration_encounters=="forest_exploration_encounters" and m.stream_positions.exploration_encounters==1,"one bounded ecological draw has its own recorded stream")
			var ids: Dictionary = {}
			for row: Dictionary in m.enemies:
				check(not ids.has(str(row.id)),"actual actor identities are unique")
				ids[str(row.id)] = true
				kinds[str(row.behavior_id)] = true
				check(str(row.geometry_instance).begins_with("district_") and not str(row.geometry_instance).begins_with("district_0_"),"first ordinary teaching district remains unpressured")
				if row.behavior_id in ["forest_bark_beetle","forest_seed_sentry"] and map_index==1:
					check(not "_main_" in str(row.geometry_instance) and (str(row.geometry_instance).ends_with("_explore") or str(row.geometry_instance).ends_with("_master")),"first-map armour/ranged encounters occupy actual optional branches instead of the old short main-route mushroom banks")
				if row.behavior_id in ["forest_bark_beetle","forest_seed_sentry","charger"] and map_index==2:
					var district := ECOLOGY._district(str(row.geometry_instance))
					var names: Array[String] = ["forest_seed_sentry","charger","forest_bark_beetle"]
					check(str(row.geometry_instance)=="district_%s_main_b" % district and str(row.behavior_id)==names[(district-1+int(m.exploration_ecology.ground_rotation))%names.size()],"second-map ground assignment retains its original district/rotation policy")
				var definition := load(str(row.definition_path)) as EnemyDefinition
				check(definition!=null and definition.is_valid() and row.definition_sha256==FileAccess.get_sha256(str(row.definition_path)) and row.stable_id==String(definition.stable_id) and row.behavior_id==String(definition.behavior_id),"placement consumes the real retained Definition/sha/stable-id")
				check(m.enemy_drops.has(str(row.id)) and m.enemy_drops[str(row.id)].get("enemy_id")==str(row.id) and m.enemy_drops[str(row.id)].get("stream_namespace")=="enemy_drops","current DropService namespace settles each actual actor")
				check(ECOLOGY._protected(m,rect(row.authored_body_sweep)).is_empty(),"complete authored body sweep protects spawn, camp and interactions")
				if not str(row.support_id).is_empty():
					var support := ECOLOGY._support(m,str(row.support_id))
					check(not support.is_empty() and absf(point(row.position).y+definition.collision_size.y*.5-rect(support.rect).position.y)<.01,"grounded actor's actual feet meet the declared real support")
				if row.behavior_id=="forest_crossbranch":
					if crossbranch_sample.is_empty(): crossbranch_sample=m.duplicate(true)
					check(row.shore_rows.size()==2 and row.shore_rows[0].id!=row.shore_rows[1].id,"moving body connects two different real shores")
					for shore: Dictionary in row.shore_rows:
						var support := ECOLOGY._support(m,str(shore.id))
						check(not support.is_empty() and support.rect==shore.rect and absf(point(shore.position).y+definition.collision_size.y*.5-rect(support.rect).position.y)<.01,"crossbranch shore uses actual support rectangle and feet")
					check(row.ballistic_path.both_directions_checked and not row.fixed_alternative_anchor_ids.is_empty(),"both ballistic directions have a retained fixed-fruit alternative")
				if row.behavior_id=="forest_bible_weaver":
					check(row.web_strands.size()==2 and row.web_strands[0].id=="upper" and row.web_strands[1].id=="lower" and float(row.web_strands[0].start[1])<float(row.web_strands[1].start[1]),"weaver alternates different actual upper/lower windows")
				if row.has("tether_host_support_id"):
					var host := ECOLOGY._support(m,str(row.tether_host_support_id))
					check(not host.is_empty() and rect(host.rect).has_point(point(row.tether_origin)),"suspended actor root lies inside its real host")
			cases.append({"seed":m.seed,"map":map_index,"actor_count":m.enemies.size(),"behaviours":m.exploration_ecology.behaviours,"omissions":m.exploration_ecology.omissions.duplicate(true)})
			if sample.is_empty() and not m.enemies.is_empty(): sample=m.duplicate(true)
	for required: String in ["forest_lantern","forest_bible_weaver","forest_crossbranch"]:
		check(kinds.has(required),"finite actual-world sample includes meaningful "+required+" habitat")
	check(kinds.size()>=6,"sample includes distinct retained ecological decisions beyond three ground-watch swaps")
	if not sample.is_empty(): counterexamples(sample)
	if not crossbranch_sample.is_empty(): crossbranch_counterexamples(crossbranch_sample)
	for map_index: int in [1,2]: await actual_app(map_index)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"cases":cases,"scope":"static placement contracts plus actual two-map App behaviour configuration; live phase traversal unverified"},"\t"))
	print("FOREST EXPLORATION ECOLOGY: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func borrow_pod_run() -> void:
	var actual_slots := 0
	for map_index: int in [1,2]:
		var m := WORLD.build("forest-ecology-app/thorn_forest/map_%s" % map_index,map_index)
		var before := geometry(m)
		ECOLOGY.install(m)
		check(geometry(m)==before,"authored pod installation preserves real world geometry, fixed fruits, routes and rewards")
		var pods := 0
		for row: Dictionary in m.enemies:
			if row.behavior_id=="forest_swing_pod": pods+=1
		check(pods<=1,"authored pod replaces the automatic canopy pod rather than doubling the encounter")
		for instance: Dictionary in m.geometry_instances:
			if str(instance.module_id)!="borrow_pod_crossing" or ECOLOGY._district(str(instance.id))<1: continue
			actual_slots+=1
			var matches: Array = m.enemies.filter(func(row: Dictionary) -> bool: return str(row.geometry_instance)==str(instance.id) and row.get("authored_slot_id")=="borrow_pod")
			check(matches.size()==1,"actual borrowing module admits its one authored moving target; unsafe omission remains a release failure")
			if matches.size()!=1:
				cases.append({"map":map_index,"instance":instance.id,"omissions":m.exploration_ecology.omissions})
				continue
			var row: Dictionary = matches[0]
			var definition := load(str(row.definition_path)) as ForestEnemyDefinition
			var slot: Dictionary = instance.local_geometry.ecology_slots.filter(func(value: Dictionary) -> bool: return value.id=="borrow_pod")[0]
			var at := point(row.position)
			var expected := Rect2(at-definition.collision_size*.5-Vector2(row.patrol_radius,definition.swing_rise),definition.collision_size+Vector2(row.patrol_radius*2.0,definition.swing_rise))
			check(rect(row.authored_body_sweep)==expected and float(row.patrol_radius)==float(slot.patrol_radius),"complete actual Definition body follows the authored radius and 70wu-rise source orbit")
			check(row.position==ECOLOGY._pair(point(instance.translation)+point(slot.position)) and str(row.support_id).is_empty(),"aerial pod home maps from the local slot without pretending to stand on its observation bank")
			check(str(row.tether_host_support_id)==str(instance.platform_id_map[str(slot.tether_host_support_id)]) and row.tether_origin==ECOLOGY._pair(point(instance.translation)+point(slot.tether_origin)),"pod tether uses the exact mapped source host and interior root")
			check(row.shore_support_ids.size()==2 and row.shore_support_ids[0]!=row.shore_support_ids[1] and not row.fixed_alternative_anchor_ids.is_empty(),"borrow module retains distinct real observation/reward shores and a fixed-fruit alternative")
			check(m.enemy_drops[str(row.id)].enemy_id==str(row.id) and m.enemy_drops[str(row.id)].stream_namespace=="enemy_drops","authored pod uses the current deterministic drop settlement including legitimate none")
			var changed := m.duplicate(true)
			changed.enemies=[]
			check(ECOLOGY._admit(changed,row).is_empty(),"actual authored pod habitat passes the unchanged body, host and interaction protection")
			changed.platforms=changed.platforms.filter(func(value: Dictionary) -> bool: return value.id!=row.tether_host_support_id)
			check(not ECOLOGY._admit(changed,row).is_empty(),"deleting the real suspension host refuses the authored pod")
			changed=m.duplicate(true);changed.enemies=[]
			changed.platforms=changed.platforms.filter(func(value: Dictionary) -> bool: return value.id!=row.shore_support_ids[1])
			check(not ECOLOGY._admit(changed,row).is_empty(),"deleting the real upper receiving branch refuses the authored pod")
			changed=m.duplicate(true);changed.enemies=[]
			changed.hook_anchors=changed.hook_anchors.filter(func(value: Dictionary) -> bool: return not row.fixed_alternative_anchor_ids.has(str(value.id)))
			check(not ECOLOGY._admit(changed,row).is_empty(),"removing the fixed-fruit fallback refuses the authored borrowing habitat")
			changed=m.duplicate(true);changed.enemies=[]
			changed.dangers.append(row.authored_body_sweep.duplicate())
			check(not ECOLOGY._admit(changed,row).is_empty(),"an actual danger covering the authored orbit refuses placement")
			changed=m.duplicate(true);changed.enemies=[]
			var forged := row.duplicate(true)
			forged.tether_origin=ECOLOGY._pair(point(row.tether_origin)+Vector2(0.0,1000.0))
			check(not ECOLOGY._admit(changed,forged).is_empty(),"a detached visual tether cannot certify a rooted encounter")
			cases.append({"map":map_index,"instance":instance.id,"actor_id":row.id,"body_sweep":row.authored_body_sweep,"scope":"placement and actual App configuration only; live H/kill/fallback not verified here"})
	check(actual_slots>0,"finite actual-world sample contains the new borrowing module, not a synthetic test-only habitat")
	for map_index: int in [1,2]: await actual_app(map_index)
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"cases":cases,"scope":"authored borrowing pod placement and real App configuration; no live traversal claim"},"\t"))
	print("FOREST EXPLORATION ECOLOGY: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func counterexamples(m: Dictionary) -> void:
	var old := m.duplicate(true)
	old.layout_version="forest-bible-world-v15"
	var before := JSON.stringify(old)
	ECOLOGY.install(old)
	check(JSON.stringify(old)==before,"helper refuses to rewrite recorded v15 ecology")
	var candidate: Dictionary = m.enemies[0].duplicate(true)
	var changed := m.duplicate(true)
	changed.enemies=[]
	changed.merchant_position=candidate.position.duplicate()
	check(not ECOLOGY._admit(changed,candidate).is_empty(),"moving camp to actor sweep rejects the candidate instead of ignoring camp protection")
	changed=m.duplicate(true)
	changed.enemies=[]
	changed.spawn=candidate.position.duplicate()
	check(not ECOLOGY._admit(changed,candidate).is_empty(),"moving initial observation to actor sweep rejects the candidate")
	changed=m.duplicate(true)
	changed.dangers.append(candidate.authored_body_sweep.duplicate())
	ECOLOGY.install(changed)
	check(not changed.enemies.any(func(row: Dictionary) -> bool: return row.id==candidate.id),"new danger cannot silently occupy the same actor habitat")
	for row: Dictionary in m.enemies:
		if row.has("tether_host_support_id"):
			changed=m.duplicate(true)
			changed.enemies=[]
			changed.platforms=changed.platforms.filter(func(value: Dictionary) -> bool: return value.id!=row.tether_host_support_id)
			check(not ECOLOGY._admit(changed,row).is_empty(),"missing real tether host rejects the suspended actor")
			break

func crossbranch_counterexamples(m: Dictionary) -> void:
	var candidate: Dictionary = {}
	for row: Dictionary in m.enemies:
		if row.behavior_id=="forest_crossbranch": candidate=row.duplicate(true);break
	var changed := m.duplicate(true)
	changed.enemies=[]
	var first_support := rect(ECOLOGY._support(m,str(candidate.support_id)).rect)
	var flight_bounds := rect(candidate.authored_body_sweep)
	check(flight_bounds.position.x<first_support.position.x or flight_bounds.end.x>first_support.end.x,"regression fixture's real flight extends beyond the first shore")
	check(ECOLOGY._admit(changed,candidate).is_empty(),"two independently supported bodies and clear two-way flight are admitted despite flight bounds spanning the gap")
	var detached := candidate.duplicate(true)
	detached.shore_rows[1].position[0]=rect(detached.shore_rows[1].rect).end.x+32.0
	check(not ECOLOGY._admit(changed,detached).is_empty(),"second ballistic shore must support the complete actual landing body")
	changed=m.duplicate(true)
	changed.enemies=[]
	changed.platforms=changed.platforms.filter(func(row: Dictionary) -> bool: return str(row.id)!=str(candidate.shore_rows[1].id))
	check(not ECOLOGY._admit(changed,candidate).is_empty(),"removing the actual far shore invalidates the ballistic habitat")
	changed=m.duplicate(true)
	changed.enemies=[]
	var start := point(candidate.shore_rows[0].position)
	var finish := point(candidate.shore_rows[1].position)
	var definition := load(str(candidate.definition_path)) as ForestEnemyDefinition
	var seconds := float(candidate.ballistic_path.outward_seconds)
	var elapsed := seconds*.5
	var vy := definition.crossbranch_rise_velocity if finish.y<start.y else definition.crossbranch_fall_velocity
	var midpoint := start+Vector2((finish.x-start.x)*.5,vy*elapsed+.5*definition.crossbranch_gravity*elapsed*elapsed)
	changed.dangers.append([midpoint.x-2.0,midpoint.y-2.0,4.0,4.0])
	check(not ECOLOGY._admit(changed,candidate).is_empty(),"a new actual danger on the airborne path invalidates the habitat instead of exempting its flight bounds")

func actual_app(map_index: int) -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",map_index,"forest-ecology-app",ThornForestRegionGenerator.DEPTH_VERSION,ECOLOGY.LAYOUT),"real App accepts explicit v16 map%s" % map_index)
	for i: int in 4:
		await physics_frame
		await process_frame
	var stage := app.stage as ThornForestRegionStage
	cases.append({"app_map":map_index,"app_status":app._status,"actual_stage":stage!=null,"assembly_ok":stage!=null and stage.assembly_ok})
	check(stage!=null and stage.assembly_ok,"real App completes v16 generation and ecology assembly; status="+app._status)
	if stage!=null and stage.assembly_ok:
		check(stage.enemies.size()==stage.generated.manifest.enemies.size(),"actual scene instances consume the complete authored ecology")
		for i: int in stage.enemies.size():
			var row: Dictionary = stage.enemy_manifest[i]
			var actor := stage.enemies[i].get_node("Actor") as EnemyActor
			check(actor!=null and actor.definition.stable_id==StringName(row.stable_id) and actor.attack_behavior!=null,"real actor dispatch consumes the declared Definition")
			if actor.attack_behavior is ForestCrossbranchBehavior:
				check((actor.attack_behavior as ForestCrossbranchBehavior).shores.size()==2,"App configures both actual ballistic shores")
			if actor.attack_behavior is ForestBibleWeaverBehavior:
				var web := actor.attack_behavior as ForestBibleWeaverBehavior
				check(web.line_configured and web.strand_rows==row.web_strands,"App configures both authored web entrances")
			if row.get("authored_slot_id")=="borrow_pod":
				check(actor.attack_behavior is ForestSwingPodBehavior and stage.enemies[i].is_in_group(&"grapple_target") and actor.attack_behavior.home==point(row.position) and actor.definition.patrol_half_width==float(row.patrol_radius),"actual App dispatches the authored pod as a moving H target with its unchanged behaviour/radius")
				var art := stage.enemies[i].get_node_or_null("Presentation")
				check(art!=null and art.has_meta(ForestBibleActors.TETHER_ATTACHMENT_METADATA) and str(art.get_meta(ForestBibleActors.TETHER_ATTACHMENT_METADATA).host_id)==str(row.tether_host_support_id),"actual presentation roots the pod tether in the exact serialized branch")
	app.abandon_run()
	for i: int in 3:
		await physics_frame
		await process_frame
	check(await AUDIO.drain_world(app),"actual App ecology audio drains before fixture exit")
	app.free()
	await process_frame

func geometry(m: Dictionary) -> String:
	return JSON.stringify([m.platforms,m.hook_anchors,m.connections,m.rewards,m.geometry_instances,m.spawn,m.merchant_position])

func point(row: Array) -> Vector2: return Vector2(float(row[0]),float(row[1]))
func rect(row: Array) -> Rect2: return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
