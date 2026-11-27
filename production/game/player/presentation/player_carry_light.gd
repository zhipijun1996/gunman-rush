class_name PlayerCarryLight
extends PointLight2D
## A local environmental light; the body keeps its authored palette in shadow.
var settings: Dictionary

func _ready() -> void:
	name = "CarryLight"
	position = FixedWorldProvider.point(settings.offset)
	color = Color(str(settings.color))
	energy = float(settings.energy)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .2, .7, 1])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,.65), Color(1,1,1,.12), Color(1,1,1,0)])
	var field := GradientTexture2D.new()
	field.gradient = gradient
	field.width = 128
	field.height = 128
	field.fill = GradientTexture2D.FILL_RADIAL
	field.fill_from = Vector2(.5,.5)
	field.fill_to = Vector2(1,.5)
	texture = field
	texture_scale = float(settings.radius)/64.0
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	shadow_filter_smooth = 1.5
	var body := PlayerPresentationRuntime.current_body(get_parent())
	var material := CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	body.material = material
