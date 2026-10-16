class_name PlainsCreativeSlice
extends Node2D
## Proposed art slice: real existing RootBell shore, presentation only.
## No physics, input, RNG, health, resource, timing or Manifest mutations.
var _ribs: Texture2D
var _shore: Texture2D
const SCORE_PATH := "res://assets/creative_direction/windchime_plains_v1/direction.json"
var stage: PlainsRegionStage
var floor_bounds := Rect2()
var home := Vector2.ZERO
var enabled := true
var _clock := 0.0
var _response := 0.0
var _bell: Sprite2D
var _root: EnemyActor
var _body_clips: Array[Rect2] = []
var _roof_clips: Array[Rect2] = []
var entries: Array[Dictionary] = []
var _direction: Dictionary = {}

func configure(source: PlainsRegionStage) -> void:
	stage = source
	enabled = OS.get_environment("PLAINS_CREATIVE_SLICE") == "1" or "--creative-direction-slice" in OS.get_cmdline_user_args()

func _ready() -> void:
	z_as_relative = false
	z_index = 0
	var admission: Dictionary = stage.generated.manifest.get("root_bell_admission", {})
	var facts: Dictionary = admission.get("physical_facts", {})
	var raw: Array = facts.get("floor_xywh", [])
	if raw.size() != 4 or not enabled:
		enabled = false
		return
	# Unadmitted assets never load in ordinary production. Review exports
	# explicitly restore the excluded candidate carrier.
	if not FileAccess.file_exists(SCORE_PATH):
		push_error("Explicit creative slice requires its direction carrier")
		enabled = false
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORE_PATH))
	if not parsed is Dictionary or parsed.get("direction_id", "") != "against_wind":
		push_error("Creative slice direction carrier mismatch")
		enabled = false
		return
	_direction = parsed
	_ribs = load("res://assets/creative_direction/windchime_plains_v1/wind_bell_ribs.png") as Texture2D
	_shore = load("res://assets/creative_direction/windchime_plains_v1/clockroot_shore.png") as Texture2D
	if _ribs == null or _shore == null:
		enabled = false
		return
	floor_bounds = Rect2(raw[0], raw[1], raw[2], raw[3])
	home = Vector2(facts.home[0], facts.home[1])
	# Every visible repaint is clipped to an actual static solid. Approved grass
	# and standing edge remain visible; these images never imply extra ledges.
	var shore_window := Rect2(floor_bounds.position + Vector2(0, 14), Vector2(floor_bounds.size.x, 360))
	var shore_material := ShaderMaterial.new()
	shore_material.shader = preload("res://scripts/art/plains_creative_shore.gdshader")
	shore_material.set_shader_parameter("shore_origin", shore_window.position)
	shore_material.set_shader_parameter("shore_width", floor_bounds.size.x)
	material = shore_material
	var roof_window := Rect2(home.x - 700, floor_bounds.position.y - 640, 1400, 490)
	for solid: Rect2 in PlainsRegionScenery.solid_supports(stage):
		var clip := solid.intersection(shore_window)
		if clip.has_area(): _body_clips.append(clip)
		# Repaint the real overhead solid as a cool, shaded mass. Its approved
		# grass top and physical underside/side silhouette remain unchanged.
		var interior := Rect2(solid.position + Vector2(2, 14), solid.size - Vector2(4, 17))
		if interior.has_area():
			var roof_clip := interior.intersection(roof_window)
			if roof_clip.has_area(): _roof_clips.append(roof_clip)
	var origin := Vector2(home.x - 510, floor_bounds.position.y - 320)
	var factor := 1020.0 / _ribs.get_width()
	for region: Rect2 in [Rect2(0, 0, 700, 1024), Rect2(700, 0, 300, 1024), Rect2(1000, 0, 536, 1024)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = _ribs
		atlas.region = region
		atlas.filter_clip = true
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = atlas
		sprite.scale = Vector2.ONE * factor
		sprite.position = origin + region.position * factor
		sprite.z_as_relative = false
		sprite.z_index = -8
		sprite.modulate = Color(0.72, 0.85, 0.84, 0.80)
		add_child(sprite)
		if region.position.x == 700:
			_bell = sprite
			sprite.set_meta("rest_x", sprite.position.x)
	for body: Node2D in stage.enemies:
		var actor := body.get_node_or_null("Actor") as EnemyActor
		if actor != null and actor.attack_behavior is RootBellBehavior:
			_root = actor
			(actor.attack_behavior as RootBellBehavior).pulse_committed.connect(_pulse_committed)
			break
	entries.append({"creative_direction": _direction.creative_direction_id, "authority_version": _direction.authority_version, "authority_sha256": _direction.authority_sha256, "status": "proposed_playable_art_slice", "consumer": str(stage.get_path()), "manifest_hash": stage.generated.manifest.manifest_hash, "floor_xywh": raw, "body_clip_count": _body_clips.size(), "collision": false, "original_enemy_timing": true, "user_aesthetic_acceptance": "unverified"})
	queue_redraw()

func _pulse_committed(_event_id: StringName, _point: Vector2) -> void:
	# React only after the real enemy commits; never advance its warning/hit.
	_response = 1.0

func _process(delta: float) -> void:
	if not enabled or _bell == null: return
	_clock += delta
	_response = maxf(0.0, _response - delta * 1.7)
	# Stone stays fixed. Only the far bell responds, on an independent visual
	# spring; original RootBell warning, pulse, recovery and audio stay intact.
	_bell.position.x = float(_bell.get_meta("rest_x")) + sin(_clock * 1.5) * 1.4 + sin(_response * PI * 3.0) * _response * 2.0

func _draw() -> void:
	if not enabled or floor_bounds.size.x <= 0: return
	var factor := floor_bounds.size.x / _shore.get_width()
	var base := floor_bounds.position + Vector2(0, 14)
	for clip: Rect2 in _body_clips:
		var source := Rect2((clip.position - base) / factor, clip.size / factor)
		draw_texture_rect_region(_shore, clip, source, Color(0.84, 0.91, 0.88))
	var roof_base := Vector2(home.x - 700, floor_bounds.position.y - 640)
	var roof_factor := 1400.0 / _shore.get_width()
	for clip: Rect2 in _roof_clips:
		var source := Rect2((clip.position - roof_base) / roof_factor, clip.size / roof_factor)
		draw_texture_rect_region(_shore, clip, source, Color(0.60, 0.75, 0.73))

func set_candidate(value: bool) -> void:
	enabled = value
	visible = value
	queue_redraw()

func measured_nodes() -> Dictionary:
	if not enabled:
		return {"enabled": false, "scope": "Unadmitted creative candidate: no texture or direction carrier loaded"}
	return {"entries": entries, "enabled": enabled, "body_clips": _body_clips.map(func(r: Rect2) -> Array: return PlainsSemanticLandscape.rect_values(r)), "roof_clips": _roof_clips.map(func(r: Rect2) -> Array: return PlainsSemanticLandscape.rect_values(r)), "score_source": SCORE_PATH, "score_sha256": FileAccess.get_sha256(SCORE_PATH), "scope": "Explicit candidate only. Actual RootBell shore body, overhead solid and middle-distance composition; original actors, mechanism, camera, UI and accepted-event audio retained. No user/device/commercial approval."}
