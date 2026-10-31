class_name PlainsRevisionWeights
extends RefCounted
## UV-only anatomy, shared by standalone and mesh deformation. No point, size,
## pose, or Texture is captured here; changing those cannot stale a weight.
## Ordinary float fields are intentional: PackedFloat32Array loses precision.
var ground_upper: float
var front_leg: float
var rear_leg: float
var patrol_head: float
var charger_head: float
var charger_foreleg: float
var hopper_hind: float
var hopper_head: float
var ground_belly: float
var charger_knee: float
var hopper_thigh: float
var hopper_ankle: float
var charger_shell: float
var upper: float
var muzzle: float
var sac: float
var leaves: float
var legs: float
var front: float
var sentry_knee: float
var wing_height: float
var left_wing: float
var right_wing: float
var body: float
var feet: float
var fan_body_fit: float
var main_stem: float
var upper_stem: float
var bell: float
var leaf: float
var upper_weight: float
var dead_bell: float
var top_left: float
var top_right: float
var landing: float

func _init(uv: Vector2, kind: StringName) -> void:
	landing = 1.0-smoothstep(.77,1.0,uv.y)
	if kind in [&"patrol", &"charger", &"hopper"]:
		ground_upper = ground_upper_at(uv)
		front_leg = smoothstep(0.50, 0.67, uv.x) * smoothstep(0.60, 0.83, uv.y)
		rear_leg = (1.0 - smoothstep(0.41, 0.58, uv.x)) * smoothstep(0.59, 0.83, uv.y)
		# Pale patrol face extends beyond the copper shoulder.
		patrol_head = smoothstep(0.66, 0.81, uv.x) * (1.0 - smoothstep(0.65, 0.81, uv.y))
		# Low jaw/horns and thick foreleg use their authored master masks.
		charger_head = smoothstep(0.62, 0.78, uv.x) * (1.0 - smoothstep(0.85, 0.98, uv.y))
		charger_foreleg = smoothstep(0.42, 0.59, uv.x) * smoothstep(0.65, 0.84, uv.y) * (1.0 - smoothstep(0.75, 0.86, uv.x))
		# The high thigh, knee and ankle share the same hind chain.
		hopper_hind = 1.0 - smoothstep(0.38, 0.57, uv.x)
		hopper_head = smoothstep(0.72, 0.86, uv.x) * (1.0 - smoothstep(0.70, 0.85, uv.y))
		ground_belly = (1.0 - smoothstep(0.59, 0.77, uv.x)) * smoothstep(0.20, 0.45, uv.y) * (1.0 - smoothstep(0.70, 0.87, uv.y))
		charger_knee = charger_foreleg*(1.0-smoothstep(.90,.99,uv.y))
		hopper_thigh = hopper_hind*(1.0-smoothstep(.83,.99,uv.y))
		hopper_ankle = hopper_hind * smoothstep(0.69, 0.87, uv.y)
		charger_shell = (1.0 - smoothstep(0.62, 0.80, uv.x)) * ground_upper
	elif kind == &"sentry":
		upper = 1.0 - smoothstep(0.67, 0.91, uv.y)
		muzzle = smoothstep(0.69, 0.81, uv.x) * (1.0 - smoothstep(0.44, 0.56, uv.y))
		sac = (1.0 - smoothstep(0.48, 0.65, uv.x)) * smoothstep(0.18, 0.34, uv.y) * (1.0 - smoothstep(0.68, 0.84, uv.y))
		leaves = (1.0 - smoothstep(0.64, 0.78, uv.x)) * (1.0 - smoothstep(0.64, 0.84, uv.y)) * (1.0 - sac * 0.85)
		legs = smoothstep(0.70, 0.91, uv.y)
		front = smoothstep(0.49, 0.70, uv.x)
		sentry_knee = legs*(1.0-smoothstep(.90,1.0,uv.y))
	elif kind == &"fan_sentry":
		wing_height = 1.0 - smoothstep(0.52, 0.74, uv.y)
		left_wing = (1.0 - smoothstep(0.32, 0.47, uv.x)) * wing_height
		right_wing = smoothstep(0.53, 0.68, uv.x) * wing_height
		body = (1.0 - smoothstep(0.16, 0.34, absf(uv.x - 0.44))) * smoothstep(0.35, 0.52, uv.y)
		feet = smoothstep(0.76, 0.94, uv.y)
		fan_body_fit = (1.0-smoothstep(.12,.27,absf(uv.x-.42)))*smoothstep(.43,.59,uv.y)*(1.0-smoothstep(.87,.99,uv.y))
	elif kind == &"root_bell":
		main_stem = 1.0 - smoothstep(0.80, 0.97, uv.y)
		upper_stem = 1.0 - smoothstep(0.45, 0.72, uv.y)
		bell = smoothstep(0.60, 0.71, uv.x) * (1.0 - smoothstep(0.46, 0.61, uv.y))
		leaf = smoothstep(0.16, 0.34, absf(uv.x - 0.5)) * (1.0 - smoothstep(0.66, 0.88, uv.y))
		upper_weight = 1.0-smoothstep(0.32,0.48,uv.y)
		dead_bell = smoothstep(0.64,0.70,uv.x)*smoothstep(0.12,0.18,uv.y)*(1.0-smoothstep(0.62,0.67,uv.y))
		top_left = (1.0-smoothstep(0.48,0.56,uv.x))*smoothstep(0.20,0.29,uv.x)*(1.0-smoothstep(0.30,0.38,uv.y))
		top_right = smoothstep(0.52,0.61,uv.x)*(1.0-smoothstep(0.13,0.22,uv.y))

static func ground_upper_at(uv: Vector2) -> float:
	return 1.0 - smoothstep(0.58, 0.80, uv.y)
