extends Node2D
## One development golden. Existing Module/Player/Traversal consumers; no replacement physics.
const GEOMETRY = preload("res://scripts/generation/forest_directional_geometry.gd")
var manifest: Dictionary
var module: PlatformingModule
var player: PlayerMotor
var controller: PlayerController
var grant_hook := true
var layout := "arch"
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var segment: SegmentRespawn
var damage_events: Array = []
var return_events: Array = []
var initial_health := 0.0
var segment_ready := false
var capture_tick := 0
func _ready() -> void:
	manifest=GEOMETRY.build_narrow() if layout=="narrow" else GEOMETRY.build()
	module=PlatformingModule.new()
	module.name="DirectionalRootArch"
	module.definition=GEOMETRY.as_module(manifest)
	if layout=="narrow":
		# This module field is rendering-only; real emitters/segment read manifest.
		module.definition.danger_bounds.clear()
		module.z_index=-1 # Exact shared danger rectangles stay visible above textures.
	module.authoring_debug=false
	add_child(module)
	for row: Dictionary in manifest.hook_anchors:
		var anchor:=GrappleAnchor.new()
		anchor.name=row.id
		anchor.position=GEOMETRY.point(row.position)
		add_child(anchor)
	player=preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position=GEOMETRY.point(manifest.spawn)
	add_child(player)
	controller=player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	if grant_hook: controller.traversal.grant(&"grapple")
	var camera:=Camera2D.new()
	camera.position=Vector2(250,-100)
	add_child(camera)
	if layout=="narrow":
		_setup_environment_damage()
	queue_redraw()
func _draw() -> void:
	if layout=="narrow":
		for row: Array in manifest.dangers:
			var danger:=GEOMETRY.rect(row)
			draw_rect(danger,Color("66314b"))
			draw_rect(danger,Color("ff738d"),false,2.0)
			var upper: bool=danger.end.y< -50
			for x: int in range(int(danger.position.x),int(danger.end.x),10):
				var edge: float=danger.end.y if upper else danger.position.y
				var inner: float=edge-12 if upper else edge+12
				draw_colored_polygon(PackedVector2Array([Vector2(x,inner),Vector2(x+5,edge),Vector2(x+10,inner)]),Color("ffb096"))
		draw_string(ThemeDB.fallback_font,Vector2(-170,-85),"OBSERVE / SIDE H / AWAY KICK / RECOIL THROUGH THORNS",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e4bc6e"))
		draw_string(ThemeDB.fallback_font,Vector2(300,-85),"WIDE BANK / RIGHT DROP / SAFE LOWER RETURN",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e4bc6e"))
		return
	draw_string(ThemeDB.fallback_font,Vector2(-180,-85),"ROOT ARCH: SIDE HOOK / AWAY KICK / RECOIL OUT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e4bc6e"))
	draw_string(ThemeDB.fallback_font,Vector2(510,-265),"CROWN / RETURN OUTSIDE ROOT",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e4bc6e"))

func _setup_environment_damage() -> void:
	# Existing production components, ordinary player's configured health. No HP grants.
	initial_health=controller.actor_resources.health.current
	lifetime=DemoLifetime.new()
	policy=FrameDamagePolicy.new()
	policy.lifetime=lifetime
	add_child(policy)
	assert(policy.register_target(&"player",controller.actor_resources.health,true))
	segment=SegmentRespawn.new()
	segment.configure(controller,lifetime)
	segment.add_anchor(&"entry",GEOMETRY.point(manifest.spawn))
	for row: Array in manifest.dangers: segment.danger_bounds.append(GEOMETRY.rect(row))
	policy.environment_return_requested.connect(_environment_return)
	policy.player_fatal.connect(_fatal)
	policy.batch_resolved.connect(_resolved)
	for index: int in manifest.dangers.size():
		var danger:=GEOMETRY.rect(manifest.dangers[index])
		var emitter:=DemoContactEmitter.new()
		emitter.policy=policy
		emitter.controller=controller
		emitter.source_id=StringName("mouth_thorns_%s"%index)
		emitter.kind=DamageRequest.Kind.ENVIRONMENT
		emitter.half_size=danger.size/2
		emitter.position=danger.get_center()
		emitter.interval=.7
		add_child(emitter)
	_activate_entry.call_deferred()
func _activate_entry() -> void:
	await get_tree().physics_frame
	segment_ready=segment.activate_anchor(&"entry")
	assert(segment_ready,"Narrow golden requires an actually safe production segment anchor")
func _environment_return() -> void:
	var before:=player.position
	var previous_epoch:=lifetime.actor_epoch
	var accepted:=segment.return_to_anchor()
	if accepted:policy.protect_player()
	return_events.append({"capture_tick":capture_tick,"physics_tick":Engine.get_physics_frames(),"accepted":accepted,"from":[before.x,before.y],"to":[player.position.x,player.position.y],"health":controller.actor_resources.health.current,"actor_epoch_before":previous_epoch,"actor_epoch_after":lifetime.actor_epoch})
func _fatal() -> void:
	lifetime.end()
	controller.die()
func _resolved(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		damage_events.append({"capture_tick":capture_tick,"physics_tick":Engine.get_physics_frames(),"request_tick":result.request.physics_tick,"source":String(result.request.source_id),"event_id":String(result.request.event_id),"kind":result.request.kind,"amount":result.request.amount,"health":result.health.current,"lethal":result.lethal,"token":result.request.token.key()})
