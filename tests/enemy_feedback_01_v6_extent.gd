extends "res://tests/enemy_feedback_01_tests.gd"
## Task-only v6 extent observations. Existing gameplay and native assertions stay
## unchanged. Each chain/species/age uses a fresh equivalent supported fixture,
## real Router bullets, ordinary engine ticks, then a paused visibility-only pair.
const HIT_OBSERVATION_FRAMES: Array[int] = [2, 6]
const DEATH_OBSERVATION_FRAMES: Array[int] = [3, 6, 12]
const ROI_HALF_WORLD := 128.0
const LISTED_SOURCES := [
	"res://tests/enemy_feedback_01_tests.gd",
	"res://game/enemies/presentation/enemy_presentation.gd",
	"res://game/presentation/actors/underworld_plains/underworld_enemy.gd",
	"res://game/enemies/presentation/enemy_feedback_01.gd",
	"res://game/enemies/presentation/enemy_feedback_01_particles.gd",
	"res://game/enemies/presentation/enemy_feedback_01_remains.gd",
	"res://game/enemies/presentation/enemy_feedback_01_body.gd",
	"res://game/enemies/presentation/enemy_feedback_01_flash.gdshader",
	"res://game/presentation/actors/art_foundation/pixel_plains_enemy.gd",
	"res://game/presentation/actors/art_foundation/windchime_enemy_visual.gd",
	"res://game/enemies/enemy_actor.gd",
	"res://game/enemies/enemy_motor.gd",
	"res://game/combat/damage/damageable.gd",
	"res://game/combat/damage/frame_damage_policy.gd",
	"res://game/combat/projectiles/player_projectile.gd",
	"res://game/combat/weapons/shoot_ability.gd",
	"res://config/player_tuning.json",
	"res://resources/enemies/plains_charger.tres",
	"res://resources/enemies/plains_diver.tres",
	"res://resources/enemies/patrol_health.tres",
	"res://assets/underworld_plains/actors/charger.png",
	"res://assets/underworld_plains/actors/aerial.png",
	"res://assets/plains_v4/spatial/actors.png",
	"res://assets/plains_v3/enemies/meadow_actions/manifest.json",
]
var extent_output := "res://build/enemy_feedback_01/v6-extent"
var extent_label := "v6"
var measurements: Array[Dictionary] = []
var frozen_sources: Dictionary = {}

func extent_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index: int in arguments.size():
		var argument := arguments[index]
		if argument.begins_with("--extent-output="):
			extent_output = argument.trim_prefix("--extent-output=")
		elif argument == "--extent-output" and index + 1 < arguments.size():
			extent_output = arguments[index+1]
		elif argument.begins_with("--extent-label="):
			extent_label = argument.trim_prefix("--extent-label=")
		elif argument == "--extent-label" and index + 1 < arguments.size():
			extent_label = arguments[index+1]

func exact_source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	var observer_path: String = get_script().resource_path
	hashes[observer_path] = FileAccess.get_sha256(observer_path)
	for path: String in LISTED_SOURCES:
		hashes[path] = FileAccess.get_sha256(path)
	# The original rendering chain resolves atlas filenames through this actual
	# manifest. Include those direct image consumers rather than a nominal path.
	var root_path := "res://assets/plains_v3/enemies/meadow_actions/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_path+"manifest.json"))
	for data: Dictionary in manifest.species.values():
		var texture_path := root_path+str(data.texture)
		hashes[texture_path] = FileAccess.get_sha256(texture_path)
	return hashes

func frozen_receipt() -> Dictionary:
	var sample := art.get("feedback_sample") as EnemyFeedback01
	var particles := art.get("feedback_particles") as EnemyFeedback01Particles
	var effect := art.get("feedback_remains") as EnemyFeedback01Remains
	var ids: Array[String] = []
	for context: Dictionary in accepted: ids.append(str(context.get("event_id","")))
	return {"HP":actor.health.current,"health_epoch":actor.health.epoch,"accepted_events":ids,"shots":shots.size(),"actor_position":enemy.global_position,"player_position":player.global_position,"brain_direction":actor.brain.direction,"AI_state":str(actor.attack_behavior.state) if actor.attack_behavior != null else "idle","AI_state_time":actor.attack_behavior.state_time if actor.attack_behavior != null else 0.0,"impact_serial":sample.impact_serial,"last_event_id":str(sample.last_event_id),"hurt_remaining":sample.hurt_remaining,"flash_remaining":sample.impact_remaining,"hurt_count":sample.accepted_hit_count,"death_count":sample.accepted_death_count,"emitted_bursts":particles.emitted_bursts,"particle_bursts":particles._bursts.duplicate(true),"death":remains_snapshot(effect)}

func visibility_pair(kind: StringName, after_frames: int, underworld: bool, path: String) -> void:
	await setup(path,underworld)
	var lethal := kind == &"death"
	var requested_hits := 3 if lethal else 1
	for _hit: int in requested_hits:
		check(await shoot_until_health_changes("v6_extent_actual_router_projectile"), "v6 extent receives genuine accepted Router projectile")
	var sample := art.get("feedback_sample") as EnemyFeedback01
	var particles := art.get("feedback_particles") as EnemyFeedback01Particles
	var effect := art.get("feedback_remains") as EnemyFeedback01Remains
	check(accepted.size() == requested_hits and sample.impact_serial == requested_hits and particles.emitted_bursts == requested_hits, "v6 extent has exactly the expected accepted HP receipts and bursts")
	check(actor.health.terminal if lethal else actor.health.current == actor.health.capacity-1, "v6 extent observes genuine lethal or nonlethal configured damage")
	var accepted_tick := Engine.get_physics_frames()
	await ticks(after_frames,"v6_extent_ordinary_ticks_after_accepted")
	var observed_tick := Engine.get_physics_frames()
	paused = true
	var consumer: CanvasItem = effect if lethal else particles
	var prior_visible := consumer.visible
	check(effect.active if lethal else not particles._bursts.is_empty(), "measured accepted effect is still active at the requested observation frame")
	var actual_age := effect.age if lethal else float(particles._bursts.back().age) if not particles._bursts.is_empty() else -1.0
	var origin_world: Vector2 = effect.global_transform*effect.bounds.get_center() if lethal else particles._bursts.back().point if not particles._bursts.is_empty() else particles.global_position
	var canvas := consumer.get_canvas_transform()
	var center := canvas*origin_world
	var half_screen := Vector2(canvas.x.length(),canvas.y.length())*ROI_HALF_WORLD
	var desired_region := Rect2i(Vector2i((center-half_screen).floor()),Vector2i((half_screen*2).ceil()))
	var before := frozen_receipt()
	var chain := "underworld" if underworld else "original"
	var prefix := String(actor.definition.stable_id)+"-"+chain+"-"+String(kind)+"-frame-%02d" % after_frames
	consumer.visible = false
	await RenderingServer.frame_post_draw
	var off := root.get_texture().get_image()
	var off_path := extent_output.path_join(prefix+"-off.png")
	check(off.save_png(off_path) == OK, "actual off-channel GPU screenshot saved")
	consumer.visible = true
	await RenderingServer.frame_post_draw
	var on := root.get_texture().get_image()
	var on_path := extent_output.path_join(prefix+"-on.png")
	check(on.save_png(on_path) == OK, "actual on-channel GPU screenshot saved")
	consumer.visible = prior_visible
	var region := desired_region.intersection(Rect2i(Vector2i.ZERO,off.get_size()))
	var minimum := region.end
	var maximum := region.position-Vector2i.ONE
	var changed := 0
	var radius_world := 0.0
	var touches_roi_border := false
	var inverse_canvas := canvas.affine_inverse()
	for y: int in range(region.position.y,region.end.y):
		for x: int in range(region.position.x,region.end.x):
			if off.get_pixel(x,y) == on.get_pixel(x,y): continue
			changed += 1
			minimum = Vector2i(mini(minimum.x,x),mini(minimum.y,y))
			maximum = Vector2i(maxi(maximum.x,x),maxi(maximum.y,y))
			radius_world = maxf(radius_world,(inverse_canvas*Vector2(x+.5,y+.5)).distance_to(origin_world))
			if x == region.position.x or y == region.position.y or x == region.end.x-1 or y == region.end.y-1:
				touches_roi_border = true
	var difference_bounds := Rect2i(minimum,maximum-minimum+Vector2i.ONE) if changed > 0 else Rect2i()
	var clipped_to_viewport := region != desired_region
	var after := frozen_receipt()
	check(changed > 0, "real accepted effect contributes actual visibility-only GPU difference pixels")
	check(not touches_roi_border and not clipped_to_viewport, "actual measured effect envelope is fully inside the world-sized observation region and viewport")
	check(before == after, "off/on observe exactly the same paused ages, gameplay, accepted events and feedback state")
	measurements.append({"species":String(actor.definition.stable_id),"definition":path,"chain":chain,"kind":String(kind),"requested_frames_after_accepted":after_frames,"accepted_physics_tick":accepted_tick,"observation_physics_tick":observed_tick,"paused_render_end_physics_tick":Engine.get_physics_frames(),"actual_age_seconds_both_frames":actual_age,"changed_pixels":changed,"difference_bbox_screen":difference_bounds,"maximum_radius_world":radius_world,"origin_world":origin_world,"origin_kind":"captured_body_bounds_center" if lethal else "actual_projectile_contact","canvas_transform":canvas,"region":region,"ROI_half_world":ROI_HALF_WORLD,"touches_roi_border":touches_roi_border,"clipped_to_viewport":clipped_to_viewport,"state_before":before,"state_after":after,"off_png":off_path,"off_png_sha256":FileAccess.get_sha256(off_path),"on_png":on_path,"on_png_sha256":FileAccess.get_sha256(on_path)})
	paused = false
	await cleanup()

func run() -> void:
	extent_arguments()
	root.size = Vector2i(1280,720)
	RenderingServer.set_default_clear_color(Color("26362f"))
	DirAccess.make_dir_recursive_absolute(extent_output)
	frozen_sources = exact_source_hashes()
	for path: String in frozen_sources:
		check(not str(frozen_sources[path]).is_empty(), "listed actual source has an exact SHA: "+path)
	for path: String in SOURCES:
		for underworld: bool in [false,true]:
			for after_frames: int in HIT_OBSERVATION_FRAMES:
				await visibility_pair(&"hit",after_frames,underworld,path)
			for after_frames: int in DEATH_OBSERVATION_FRAMES:
				await visibility_pair(&"death",after_frames,underworld,path)
	var final_sources := exact_source_hashes()
	check(frozen_sources == final_sources, "all listed actual source bytes remain frozen through GPU measurement")
	var file := FileAccess.open(extent_output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"ENEMY-FEEDBACK-01","label":extent_label,"checks":checks,"failures":failures,"viewport":[1280,720],"fixed_fps_expected":60,"driver_source_path":get_script().resource_path,"driver_source_sha256":FileAccess.get_sha256(get_script().resource_path),"source_sha256":frozen_sources,"source_sha256_after":final_sources,"source_stable":frozen_sources==final_sources,"measurements":measurements,"fixture":"fresh equivalent supported base arena for each species/chain/age; unchanged Definitions/AI/HP and real Router bullets; no gameplay RNG or seed override","scope":"same-state visibility-only actual GPU extent for accepted hit 2/6 frames and accepted death 3/6/12 frames across both rendering chains; listed consumer/source closure, not full-repository snapshot, subjective quality, player impact or device certification"},"\t"))
	file.close()
	print("ENEMY_FEEDBACK_01_V6_EXTENT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
