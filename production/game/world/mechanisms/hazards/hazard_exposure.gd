class_name WorldHazardExposure
extends RefCounted

## Source-local exposure state. Damage still goes through the frame arbitration.
var touching := false
var segment := 0
var pulse := 0
var cooldown := 0.0
var controller: PlayerController
var policy: FrameDamagePolicy
var source_id: StringName
var settings: Dictionary

func init(context: Dictionary, instance_id: String, profile: Dictionary) -> void:
	controller = context.controller
	policy = context.policy
	source_id = StringName(str(context.room.room_id)+":"+instance_id)
	settings = profile

func update(duration: float, contact: bool, protected: bool) -> void:
	if not contact:
		touching = false
		return
	if not touching:
		segment += 1
		pulse = 0
		cooldown = 0
		touching = true
	if protected or not controller.active or not policy.lifetime.active: return
	var left := duration
	while left > cooldown:
		left -= cooldown
		cooldown = settings.interval
		pulse += 1
		var request := DamageRequest.new()
		request.token = policy.lifetime.token()
		request.actor_epoch = policy.lifetime.actor_epoch
		request.health_epoch = controller.actor_resources.health.epoch
		request.target_id = &"player"
		request.source_id = source_id
		request.event_id = StringName("%s:%d:%d:%d" % [source_id, request.actor_epoch, segment, pulse])
		request.kind = DamageRequest.Kind.ENVIRONMENT
		request.hazard_category = StringName(settings.category)
		request.amount = settings.amount
		request.physics_tick = Engine.get_physics_frames()
		policy.submit(request)
	cooldown -= left

func snapshot() -> Dictionary:
	return {"touching":touching,"segment":segment,"pulse":pulse,"cooldown":cooldown}

func restore(data: Dictionary) -> void:
	touching = data.get("touching",false)
	segment = int(data.get("segment",0))
	pulse = int(data.get("pulse",0))
	cooldown = maxf(0,float(data.get("cooldown",0)))
