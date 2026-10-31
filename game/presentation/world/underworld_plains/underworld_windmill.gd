class_name UnderworldWindmill
extends Node2D
## Noninteractive separated art: rooted body, measured axle, independent rotor.
## The same original display bounds/root span constrain the full moving sweep.
const BODY := preload("res://assets/underworld_plains/windmill_fine_05/body.png")
const ROTOR := preload("res://assets/underworld_plains/windmill_fine_05/rotor.png")
const FLAG := preload("res://assets/underworld_plains/windmill_fine_05/flag.png")
const FLAG_SHADER := preload("res://game/presentation/world/underworld_plains/parallax_flag.gdshader")
const FRAME := Vector2(80,152)
const FOOT := Vector2(40,152)
const HUB := Vector2(42,37)
const INSET := 7.0
var rotor: Sprite2D
var flag: Sprite2D
var logical_foot := Vector2.ZERO
var original_bounds := Rect2()
var fitted_bounds := Rect2()
var _source: WeakRef
var _seconds := 0.0
var _initial_angle := 0.0

static func attach(sprite: Sprite2D,logical_root: Vector2) -> Node2D:
	if sprite==null or sprite.texture==null: return null
	if sprite.has_meta("fine_windmill_module"):
		return (sprite.get_meta("fine_windmill_module") as WeakRef).get_ref() as Node2D
	if not sprite.visible: return null
	var parent:=sprite.get_parent()
	if parent==null: return null
	var bounds: Rect2=sprite.transform*sprite.get_rect()
	var root:=logical_root+Vector2(0,INSET)
	# Fit each side independently around the real logical root: original atlas
	# feet are slightly asymmetric, so width-only fitting would widen one side.
	var fit:=minf((root.x-bounds.position.x)/FOOT.x,(bounds.end.x-root.x)/(FRAME.x-FOOT.x))
	fit=minf(fit,(root.y-bounds.position.y)/FOOT.y)
	if fit<=0.0 or root.y>bounds.end.y+.01: return null
	var result:=UnderworldWindmill.new()
	result.name=str(sprite.name)+"_FineWindmill"
	result.logical_foot=logical_root
	result.original_bounds=bounds
	result.fitted_bounds=Rect2(root-FOOT*fit,FRAME*fit)
	result.position=result.fitted_bounds.position
	result.scale=Vector2.ONE*fit
	result.z_index=sprite.z_index
	result._source=weakref(sprite)
	result._initial_angle=fposmod(logical_root.x*.003+logical_root.y*.002,TAU)
	result.set_meta("presentation_only",true)
	result.set_meta("pixel_world_units",1.0)
	result.set_meta("windmill_source_bounds",bounds)
	result.set_meta("windmill_fitted_bounds",result.fitted_bounds)
	result.set_meta("logical_foot",logical_root)
	result.set_meta("visual_root",root)
	result.set_meta("root_inset_wu",INSET)
	result.set_meta("rotor_alpha_sweep_radius",34.0*fit)
	parent.add_child(result)
	# Sibling module stays visible; retained original owns old metadata/light
	# anchors but its baked-in blades are never drawn behind the moving rotor.
	sprite.set_meta("fine_windmill_module",weakref(result))
	sprite.hide()
	return result

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var body:=Sprite2D.new()
	body.name="RootedStaticTower"
	body.centered=false
	body.texture=BODY
	body.position=Vector2(0,30)
	add_child(body)
	rotor=Sprite2D.new()
	rotor.name="IndependentBladeRotor"
	rotor.texture=ROTOR
	rotor.position=HUB
	rotor.rotation=_initial_angle
	add_child(rotor)
	flag=Sprite2D.new()
	flag.name="FixedPoleWindFlag"
	flag.centered=false
	flag.texture=FLAG
	flag.position=Vector2(59,62)
	var material:=ShaderMaterial.new()
	material.shader=FLAG_SHADER
	flag.material=material
	add_child(flag)

func _process(delta: float) -> void:
	if _source!=null and _source.get_ref()==null:
		queue_free()
		return
	_seconds+=delta
	# Rotor moves, axle/root/body never do. All native artwork stays inside a
	# 34wu circle at every angle; no collision or interaction depends on this.
	rotor.rotation=_initial_angle+_seconds*.17+sin(_seconds*.23)*.04
	var offset:=roundf(sin(_seconds*.8+_initial_angle)*.9)
	(flag.material as ShaderMaterial).set_shader_parameter("wind_offset_wu",offset)

func presentation_snapshot() -> Dictionary:
	return {"source_bounds":original_bounds,"fitted_bounds":fitted_bounds,"logical_foot":logical_foot,"visual_root":logical_foot+Vector2(0,INSET),"rotor_hub":to_global(HUB),"rotor_angle":rotor.rotation if is_instance_valid(rotor) else _initial_angle,"root_moves":false,"static_body_rotates":false,"collision":false}

func _exit_tree() -> void:
	if _source==null: return
	var sprite:=_source.get_ref() as Sprite2D
	if sprite!=null and sprite.is_inside_tree():
		sprite.show()
		sprite.remove_meta("fine_windmill_module")
