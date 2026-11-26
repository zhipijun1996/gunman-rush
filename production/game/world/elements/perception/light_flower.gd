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
var art: Texture2D
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art = LightInstrumentArt.texture(self,"switch.light")
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
	var charge := 1.0 if desired else 0.0
	if phase == "charging": charge = clampf(elapsed/maxf(activate_delay_s,0.001),0,1)
	if charge > 0.0: LightInstrumentArt.glow(self,Vector2.ZERO,charge,18)
	# Both exposures share their roots; the head sits over the light sample point.
	var center := Vector2(0,10)
	if charge < 1.0:
		LightInstrumentArt.draw(self,art,LightInstrumentArt.Frame.BUD,center)
	if charge > 0.0:
		LightInstrumentArt.draw(self,art,LightInstrumentArt.Frame.BLOOM,center,Color(1,1,1,charge))
	# Gold and blue inlays at the foot identify the light families this flower reads.
	if "local_light" in light_source_types:
		draw_rect(Rect2(-6,30,3,3),Color("e6b770"))
	if "equipped_light" in light_source_types:
		draw_colored_polygon(PackedVector2Array([Vector2(3,32),Vector2(6,29),Vector2(8,32),Vector2(5,35)]),Color("9fcbd0"))
	if brightness > 0.0:
		draw_rect(Rect2(-2,-2,4,3),Color("756044").lerp(Color("fff2be"),brightness))
	if desired != accepted:
		draw_arc(Vector2.ZERO,17,-PI*0.8,-PI*0.2,10,Color("dfaf6e"),1)
		draw_arc(Vector2.ZERO,17,PI*0.2,PI*0.8,10,Color("dfaf6e"),1)
