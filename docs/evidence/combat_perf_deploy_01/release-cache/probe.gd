extends SceneTree
const Base = preload("/workspace/refactor-evidence/combat-perf-deploy-01/release-cache/baseline_art.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	if OS.has_feature("editor"):
		push_error("Release cache experiment requires a non-editor template")
		quit(1)
		return
	var baseline = Base.BaselineArt
	var clip := baseline.entity_clip(&"small_drone", &"P14")
	if clip != ItemArtLibrary.entity_clip(&"small_drone", &"P14"):
		push_error("Different current drone clip")
		quit(1)
		return
	baseline.frame_texture(clip, 0.0)
	ItemArtLibrary.frame_texture(clip, 0.0)
	var rows: Array = []
	for batch: int in 6:
		var times := [0.0,0.0]
		for frame: int in 100:
			for variant: int in ([0,1] if frame%2==0 else [1,0]):
				var started := Time.get_ticks_usec()
				for drone: int in 3:
					if variant == 0:
						baseline.entity_clip(&"small_drone", &"P14")
						baseline.entity_clip(&"small_drone_trail", &"P14")
						baseline.clip_pose(clip, Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, 9.0, Vector2.ZERO)
						baseline.frame_texture(clip, float(frame)/60.0)
						baseline.entity_has_variants(&"small_drone", &"P14")
					else:
						ItemArtLibrary.entity_clip(&"small_drone", &"P14")
						ItemArtLibrary.entity_clip(&"small_drone_trail", &"P14")
						ItemArtLibrary.clip_pose(clip, Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO, 9.0, Vector2.ZERO)
						ItemArtLibrary.frame_texture(clip, float(frame)/60.0)
						ItemArtLibrary.entity_has_variants(&"small_drone", &"P14")
					times[variant] += float(Time.get_ticks_usec()-started)/100.0/1000.0
		rows.append({"baseline_ms":times[0],"candidate_ms":times[1]})
	var a := baseline.frame_texture(clip,.31) as AtlasTexture
	var b := ItemArtLibrary.frame_texture(clip,.31) as AtlasTexture
	var same := a.atlas == b.atlas and a.region == b.region and baseline.clip_pose(clip,Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,9.0,Vector2.ZERO) == ItemArtLibrary.clip_pose(clip,Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,9.0,Vector2.ZERO)
	print("RELEASE_CACHE_PROBE "+JSON.stringify({"editor":OS.has_feature("editor"),"standalone":OS.has_feature("standalone"),"clip":clip,"same_atlas_region_pose":same,"rows":rows,"scope":"Approved native non-editor release template, same process alternates old exact source and candidate on same project assets. Warm three-drone five-query chain only; excludes draw/GPU/search/world/phone. No whole-frame FPS claim."}))
	a = null
	b = null
	baseline.clear_cache()
	ItemArtLibrary.clear_cache()
	quit(0 if same else 1)
