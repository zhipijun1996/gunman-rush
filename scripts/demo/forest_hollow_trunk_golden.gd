extends Node2D
## Development-only real module/player/policy consumer; no alternate movement.
var manifest: Dictionary
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
	manifest=ForestHollowTrunkGeometry.build(return_style)
	var module := PlatformingModule.new()
	module.definition=ForestHollowTrunkGeometry.as_module(manifest)
	module.authoring_debug=false
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
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results: damage_events.append({"tick":tick,"event_id":String(result.request.event_id),"amount":result.request.amount,"hp":result.health.current}))
	policy.environment_return_requested.connect(func() -> void: return_events.append({"tick":tick,"returned":segment.return_to_anchor()}))
	camera=Camera2D.new()
	camera.position=Vector2(180,-30)
	add_child(camera)
	_activate.call_deferred()
func _activate() -> void:
	await get_tree().physics_frame
	assert(segment.activate_anchor(&"entry"))
func _draw() -> void:
	for row: Dictionary in manifest.windows:
		draw_rect(ForestDirectionalGeometry.rect(row.clear_rect),Color(.2,.6,.45,.12))
	draw_string(ThemeDB.fallback_font,Vector2(-200,-150),"HOLLOW TRUNK / UPPER WINDOW OUT / LOWER HOLLOW RETURN",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e7d18c"))

func _process(_delta: float) -> void:
	if is_instance_valid(player): camera.position=player.position+Vector2(180,-60)
