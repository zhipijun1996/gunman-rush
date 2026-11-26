@tool
class_name WorldLightFlower
extends Node2D
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export var links: Array[Dictionary] = []
@export var light_source_types: Array[String] = ["local_light","equipped_light"]
@export var light_threshold := 0.50
@export var activate_delay_s := 0.20
@export var release_hold_s := 0.40
var network: WorldLightNetwork
var runtime: WorldElementRuntime
var submit: Callable
var phase := "dark"
var elapsed := 0.0
var accepted := false
var desired := false
var brightness := 0.0

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.light_threshold <= 0 or p.light_threshold > 1: return "light_threshold:outside_(0,1]"
	var seen := {}
	for source: Variant in p.light_source_types:
		if source not in ["local_light","equipped_light"] or seen.has(source): return "light_source_types:invalid_or_duplicate"
		seen[source] = true
	return "light_source_types:required" if seen.is_empty() else ""

static func control_dependencies(doc: Dictionary) -> Dictionary:
	return WorldLightNetwork.control_dependencies(doc)

func element_bind(context: Dictionary) -> void:
	network = WorldLightNetwork.of(context.room)
	network.controller = context.controller
	network.register_light_object(element_id,self,network.flowers)
	runtime = context.runtime; submit = context.submit

func sample_light(delta: float) -> void:
	brightness = network.sample(global_position,light_source_types)
	var illuminated := brightness >= light_threshold
	if desired == illuminated:
		phase = "active" if desired else "dark"; elapsed = 0.0
	else:
		phase = "charging" if illuminated else "release_hold"
		elapsed += delta
		if elapsed >= (activate_delay_s if illuminated else release_hold_s):
			desired = illuminated
			phase = "active" if desired else "dark"; elapsed = 0.0
	if can_commit(): submit.call(element_id)
	queue_redraw()

func can_commit() -> bool: return desired != accepted and runtime.can_signal(self,desired)
func element_state() -> Dictionary: return {"active":accepted,"phase":phase,"elapsed":elapsed}
func proposed_state() -> Dictionary:
	var result := element_state(); result.active = desired; return result
func element_signal() -> Dictionary: return {"output":"active","value":desired}
func element_restore(data: Dictionary) -> void:
	accepted = data.active; phase = data.phase; elapsed = data.elapsed
	desired = phase in ["active","release_hold"]
func reset_attempt() -> void:
	accepted = false
	desired = false
	elapsed = 0.0
	brightness = 0.0
	phase = "dark"
	queue_redraw()

func accept_committed() -> void: queue_redraw()

func _draw() -> void:
	var aperture := 1.0 if desired else (elapsed/maxf(activate_delay_s,0.001) if phase == "charging" else 0.0)
	draw_line(Vector2.ZERO,Vector2(0,16),Color("6c775c"),3)
	# The base identifies accepted light families even while the petals are closed.
	if "local_light" in light_source_types:
		draw_rect(Rect2(-7,12,4,5),Color("dbb76c"))
	if "equipped_light" in light_source_types:
		draw_colored_polygon(PackedVector2Array([Vector2(3,14),Vector2(8,11),Vector2(8,17)]),Color("a5c7cb"))
	for i: int in 6:
		var axis := Vector2.RIGHT.rotated(i*TAU/6)
		var tip := axis*(7.0+aperture*8.0)
		draw_colored_polygon(PackedVector2Array([axis*2,axis*5+axis.orthogonal()*3,tip,axis*5-axis.orthogonal()*3]),Color("9c8c65").lerp(Color("f6df8c"),aperture))
	draw_circle(Vector2.ZERO,3,Color("534c48").lerp(Color("fff1b6"),brightness))
	if desired != accepted: draw_arc(Vector2.ZERO,17,0,TAU,24,Color("d29c62"),1)
