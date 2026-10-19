extends Node2D
## Development-only real module/player/policy consumer; no alternate movement.
var manifest: Dictionary
var geometry_override: Dictionary = {}
var return_style := "deep_zeroR"
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var segment: SegmentRespawn
var camera: Camera2D
var grant_hook := true
var damage_events: Array = []
var return_events: Array = []
var tick := 0
func _ready() -> void:
	manifest=geometry_override.duplicate(true) if not geometry_override.is_empty() else ForestHollowTrunkGeometry.build(return_style)
	var module := PlatformingModule.new()
	module.definition=ForestHollowTrunkGeometry.as_module(manifest)
	module.authoring_debug=false
	if manifest.has("cavity_contract"):
		module.definition.danger_bounds.clear() # Exact cavity overlay below; legacy module interprets ceiling as DEEP DROP.
		module.z_index=-1
	add_child(module)
	for row: Dictionary in manifest.hook_anchors:
		var anchor := GrappleAnchor.new()
		anchor.name=row.id
		anchor.position=ForestDirectionalGeometry.point(row.position)
		add_child(anchor)
	player=preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position=ForestDirectionalGeometry.point(manifest.spawn)
	add_child(player)
	controller=player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	if grant_hook: controller.traversal.grant(&"grapple")
	policy=FrameDamagePolicy.new()
	policy.lifetime=lifetime
	add_child(policy)
	assert(policy.register_target(&"player",controller.actor_resources.health,true))
	segment=SegmentRespawn.new()
	segment.configure(controller,lifetime)
	segment.add_anchor(&"entry",ForestDirectionalGeometry.point(manifest.spawn))
	for index: int in manifest.dangers.size():
		var danger := ForestDirectionalGeometry.rect(manifest.dangers[index])
		segment.danger_bounds.append(danger)
		var emitter := DemoContactEmitter.new()
		emitter.policy=policy
		emitter.controller=controller
		emitter.source_id=StringName("hollow_thorns_%s"%index)
		emitter.kind=DamageRequest.Kind.ENVIRONMENT
		emitter.half_size=danger.size/2
		emitter.position=danger.get_center()
		emitter.interval=.7
		add_child(emitter)
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results: damage_events.append({"tick":tick,"event_id":String(result.request.event_id),"amount":result.request.amount,"hp":result.health.current,"source":String(result.request.source_id),"kind":result.request.kind,"request_tick":result.request.physics_tick,"actor_epoch":lifetime.actor_epoch}))
	policy.environment_return_requested.connect(_environment_return)
	camera=Camera2D.new()
	camera.position=Vector2(180,-30)
	add_child(camera)
	_activate.call_deferred()
func _environment_return() -> void:
	var before := player.position
	var epoch_before := lifetime.actor_epoch
	var accepted := segment.return_to_anchor()
	if accepted:policy.protect_player()
	return_events.append({"tick":tick,"returned":accepted,"from":[before.x,before.y],"to":[player.position.x,player.position.y],"actor_epoch_before":epoch_before,"actor_epoch_after":lifetime.actor_epoch})
func _activate() -> void:
	await get_tree().physics_frame
	assert(segment.activate_anchor(&"entry"))
func _draw() -> void:
	for row: Dictionary in manifest.windows:
		draw_rect(ForestDirectionalGeometry.rect(row.clear_rect),Color(.2,.6,.45,.12))
	if manifest.has("cavity_contract"):
		# Render the exact Policy rectangles, including the ceiling facing down.
		# No terrain envelope or decorative spike changes the actual danger bounds.
		for index: int in manifest.dangers.size():
			var danger := ForestDirectionalGeometry.rect(manifest.dangers[index])
			draw_rect(danger,Color("66314b"))
			draw_rect(danger,Color("ff738d"),false,2.0)
			var ceiling: bool=danger.position.y< -400
			var presentations: Array=manifest.get("danger_presentations",[])
			if index<presentations.size() and presentations[index] is Dictionary:
				ceiling=String(presentations[index].get("facing","down" if ceiling else "up"))=="down"
			for x: int in range(int(danger.position.x),int(danger.end.x),12):
				var edge: float=danger.end.y if ceiling else danger.position.y
				var base: float=danger.position.y if ceiling else danger.end.y
				draw_colored_polygon(PackedVector2Array([Vector2(x,base),Vector2(minf(x+12,danger.end.x),base),Vector2(minf(x+6,danger.end.x),edge)]),Color("ffd6a5"))
		return
	draw_string(ThemeDB.fallback_font,Vector2(-200,-150),"HOLLOW TRUNK / UPPER WINDOW OUT / LOWER HOLLOW RETURN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e7d18c"))

func _process(_delta: float) -> void:
	if is_instance_valid(player): camera.position=player.position+Vector2(180,-60)
