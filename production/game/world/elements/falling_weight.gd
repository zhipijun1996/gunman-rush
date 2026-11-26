class_name WorldFallingWeight
extends MechanismSolid

@export var body_size := Vector2(64,64)
@export var landing_offset := Vector2(0,192)
@export var release_delay_s := 0.4
@export var pressure_weight := false
var phase := "hanging"
var remaining := 0.0
var speed := 0.0
var danger: DemoContactEmitter
var struck_enemies := {}
var room: FixedWorldRoom

func _ready() -> void:
	make_solid(body_size)
	shot_part(Vector2.UP*(body_size.y*0.5+9),12)
	add_to_group(&"mechanism_pressure_weight")

func element_bind(context: Dictionary) -> void:
	super(context)
	room = context.room
	danger = make_hazard(Rect2(-body_size/2,body_size))
	danger.enabled = false

func pressure_bounds() -> Rect2:
	if not pressure_weight or phase != "settled": return Rect2()
	return Rect2(body.global_position-body_size/2,body_size)

func element_can_receive(input: String,value: Variant) -> bool:
	return input == "release" and value == null and phase == "hanging"

func element_state() -> Dictionary:
	return {"phase":phase,"remaining":remaining,"speed":speed,"offset_y":body.position.y,"receipts":shot_receipts.duplicate(),"struck":struck_enemies.duplicate()}

func element_propose(_input: String,_value: Variant) -> Dictionary:
	var data := element_state()
	data.phase = "warning"
	data.remaining = release_delay_s
	return data

func element_restore(data: Dictionary) -> void:
	phase = data.phase
	hit_part.collision_layer = 8 if phase in ["hanging","warning"] else 0
	remaining = data.remaining
	speed = data.speed
	body.position.y = data.offset_y
	shot_receipts = data.get("receipts",{}).duplicate()
	struck_enemies = data.get("struck",{}).duplicate()
	if danger != null:
		danger.position = body.position
		danger.enabled = phase == "falling"
	queue_redraw()

func mechanism_shot(context: Dictionary) -> bool:
	if not accept_shot(context): return false
	if element_can_receive("release",null): element_restore(element_propose("release",null))
	return true

func _physics_process(delta: float) -> void:
	if controller == null or not lifetime.active: return
	if phase == "settled":
		danger.enabled = false
		return
	if phase == "warning":
		remaining = maxf(0,remaining-delta)
		if remaining <= 0:
			phase = "falling"
			hit_part.collision_layer = 0
		queue_redraw()
	if phase != "falling": return
	danger.enabled = true
	speed = minf(controller.motor.tuning.max_normal_fall_speed,speed+controller.motor.tuning.gravity*delta)
	var travel := minf(landing_offset.y-body.position.y,speed*delta)
	# Ground defines the landing. If there is no support at the authored
	# destination, the terminal receipt must never be issued.
	var fraction := travel_fraction(Vector2.DOWN*maxf(travel,0.2),true)
	var distance := minf(travel,maxf(travel,0.2)*fraction)
	var swept := Rect2(body.global_position-body_size/2,body_size+Vector2.DOWN*distance)
	for id: String in room.enemies:
		var actor: EnemyActor = room.enemies[id]
		if actor.health.terminal or struck_enemies.has(id): continue
		if not swept.grow_individual(actor.definition.collision_size.x/2,actor.definition.collision_size.y/2,actor.definition.collision_size.x/2,actor.definition.collision_size.y/2).has_point(actor.motor.global_position): continue
		var request := DamageRequest.new()
		request.target_id = StringName(id)
		request.source_id = StringName(element_id)
		request.kind = DamageRequest.Kind.ENVIRONMENT
		request.amount = danger.amount
		request.token = lifetime.token()
		request.actor_epoch = lifetime.actor_epoch
		request.health_epoch = actor.health.epoch
		request.event_id = StringName("%s:%s:%s" % [room.room_id,element_id,id])
		policy.submit(request)
		struck_enemies[id] = true
	body.position.y += distance
	body.force_update_transform()
	danger.position = body.position
	blocked = fraction < 0.99999
	if blocked:
		speed = 0
		if absf(body.position.y-landing_offset.y) < 0.25:
			phase = "settled"
	queue_redraw()

func result_at_terminal(kind: String) -> bool:
	return kind == "settle_block" and phase == "settled"

func install_terminal(kind: String) -> void:
	if kind != "settle_block": return
	phase = "settled"
	hit_part.collision_layer = 0
	speed = 0
	body.position = landing_offset
	if danger != null: danger.enabled = false
	queue_redraw()

func _draw() -> void:
	if body == null: return
	var top := Vector2(0,-body_size.y*.5)
	MechanismRegionArt.stamp(self,"mount",top+Vector2.UP*26,Vector2(33,20))
	if phase in ["hanging","warning"]:
		BellGateArt.chain(self,0,top.y-22,top.y)
		BeamHardware.part(self,BeamHardware.BOSS,top+Vector2.UP*9,Vector2(19,19))
		draw_rect(Rect2(-2,top.y-10,4,3),BeamHardware.SIGNAL if phase=="warning" else BeamHardware.BRASS)
	BeamHardware.ballast(self,Rect2(body.position-body_size/2,body_size),pressure_weight,false)
