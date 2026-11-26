@tool
class_name WorldSoundLure
extends Node2D
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export_enum("shot","ground_contact") var trigger_mode := "shot"
@export var bounds := Rect2(0,0,160,16)
@export var audible_radius := 320.0
@export var investigation_s := 3.0
@export var cooldown_s := 2.0
@export var stand_search_radius := 96.0
const CHARM := preload("res://assets/world_elements/guide_light/sound_charm.png")
const MAT := preload("res://assets/world_elements/guide_light/leaf_mat.png")
var charm_art: Texture2D = CHARM
var mat_art: Texture2D = MAT
var room: FixedWorldRoom
var controller: PlayerController
var lifetime: DemoLifetime
var body: StaticBody2D
var cooldown_left := 0.0
var serial := 0
var contacting := false
var baseline := true
var last_emission := Vector2.ZERO
var ripple := 1.0
var packets := {}
var linked_actors: Array[EnemyActor] = []

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.audible_radius <= 0 or p.investigation_s <= 0 or p.stand_search_radius <= 0:
		return "audible_radius/investigation_s/stand_search_radius:positive_required"
	return ""

func element_bind(context: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	charm_art = load(WorldElementCatalog.skin_value(self,"interaction.sound_lure","charm_texture",CHARM.resource_path))
	mat_art = load(WorldElementCatalog.skin_value(self,"interaction.sound_lure","mat_texture",MAT.resource_path))
	room = context.room; controller = context.controller; lifetime = context.lifetime
	process_physics_priority = 1150
	body = StaticBody2D.new()
	var collision := CollisionShape2D.new()
	if trigger_mode == "ground_contact":
		var rect := RectangleShape2D.new(); rect.size = bounds.size
		body.position = bounds.get_center()-position
		body.collision_layer = 1
		collision.shape = rect
	else:
		var circle := CircleShape2D.new(); circle.radius = 12
		body.collision_layer = 8; collision.shape = circle
	body.collision_mask = 0; body.add_child(collision); add_child(body)
	controller.motor.repositioned.connect(rebase)
	controller.motor.weapon_blinked.connect(func(_from: Vector2,_to: Vector2): rebase())
	tree_exiting.connect(cancel_investigations,CONNECT_ONE_SHOT)

func reset_attempt() -> void:
	cancel_investigations()
	packets.clear()
	serial = 0
	cooldown_left = 0.0
	contacting = false
	baseline = true
	last_emission = Vector2.ZERO
	ripple = 1.0
	queue_redraw()

func rebase() -> void: baseline = true
func cancel_investigations() -> void:
	for actor: EnemyActor in linked_actors:
		if is_instance_valid(actor) and actor.investigation_owner == self: actor.cancel_investigation()
	linked_actors.clear()

func mechanism_shot(context: Dictionary) -> bool:
	var packet := str(context.get("packet_id",""))
	if trigger_mode != "shot" or packet.is_empty() or packets.has(packet): return false
	packets[packet] = true
	if not ready_to_sound(): return false
	emit_sound(global_position,serial+1)
	return true

func ready_to_sound() -> bool:
	return cooldown_left <= 0 and lifetime != null and lifetime.active and controller.active and not controller.actor_resources.health.terminal

func emit_sound(at: Vector2, next_serial: int) -> void:
	serial = next_serial
	last_emission = at
	ripple = 0.0; cooldown_left = cooldown_s
	if trigger_mode == "shot": GameAudio.cue(self,&"mechanism_bell")
	else:
		var mixer := GameAudio.for_origin(self) as GameAudio
		if mixer != null: mixer.play(&"land",preload("res://assets/audio/plains_feedback_02/plant_land.wav"))
	linked_actors = linked_actors.filter(func(actor): return is_instance_valid(actor) and actor.investigation_owner == self)
	for actor: EnemyActor in room.enemies.values():
		if actor.motor.global_position.distance_to(at) <= audible_radius and actor.investigate(self,at,stand_search_radius,investigation_s):
			if actor not in linked_actors: linked_actors.append(actor)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller): return
	cooldown_left = maxf(0.0,cooldown_left-delta)
	if ripple < 1.0:
		ripple = minf(1.0,ripple+delta/0.45)
		queue_redraw()
	if trigger_mode != "ground_contact": return
	var contact := Vector2.INF
	var motor := controller.motor
	if controller.active and not controller.actor_resources.health.terminal and motor.is_on_floor():
		for i: int in motor.get_slide_collision_count():
			var hit := motor.get_slide_collision(i)
			if hit.get_collider() == body and hit.get_normal().dot(Vector2.UP) >= cos(motor.floor_max_angle):
				contact = hit.get_position()
				break
	var on_mat := contact.is_finite()
	if on_mat and not contacting and not baseline and ready_to_sound(): emit_sound(contact,serial+1)
	contacting = on_mat
	baseline = false

func element_can_receive(input: String,value: Variant) -> bool: return input == "sound" and value == null and ready_to_sound()
func element_state() -> Dictionary: return {"serial":serial,"cooldown":cooldown_left}
func element_propose(_input: String,_value: Variant) -> Dictionary: return {"serial":serial+1,"cooldown":cooldown_s}
func element_restore(data: Dictionary) -> void:
	if data.serial > serial:
		var at := global_position if trigger_mode == "shot" else room.to_global(bounds.position+Vector2(bounds.size.x/2,0))
		emit_sound(at,int(data.serial))
	else: cooldown_left = data.cooldown

func _draw() -> void:
	if trigger_mode == "shot":
		var origin := -(charm_art.get_size()*Vector2(0.80,0.62)).round()
		draw_texture(charm_art,origin,Color("b1a48e") if cooldown_left > 0 else Color.WHITE)
	else:
		var rect := Rect2(bounds.position-position,bounds.size)
		LightInstrumentArt.draw_bank(self,mat_art,rect)
	if ripple < 1.0:
		draw_arc(to_local(last_emission),maxf(1,audible_radius*ripple),0,TAU,48,Color(0.9,0.78,0.52,1-ripple),2)
