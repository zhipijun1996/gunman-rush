class_name GrappleAnchor
extends Area2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var hang_enabled := false
@export_enum("inherit", "clockwork", "rootbound") var material_family := "inherit"
@export var cooldown_s := 0.0
@export var initial_available := true
@export var reactivate_warning_s := 0.25
var remaining := 0.0
var hook_session := ""
var holder: TraversalAbility
var attached := false
var clock := 0.0
var struck := 0.0
var artwork: Sprite2D

func _ready() -> void:
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 12
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	artwork = Sprite2D.new()
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var kind := "hang" if hang_enabled else "bounce"
	var path := "res://assets/world_traversal/native/%s_%s.png" % [material_family,kind]
	if material_family == "inherit":
		path = WorldElementCatalog.skin_value(self,"traversal.hook",kind+"_texture","res://assets/world_traversal/native/clockwork_%s.png"%kind)
	artwork.texture = load(path)
	artwork.offset = Vector2(1,3) if hang_enabled else Vector2(1,-7)
	add_child(artwork)
	reset_availability()

func reset_availability() -> void:
	if is_instance_valid(holder) and holder.hook_target == self: holder.cancel()
	holder = null
	hook_session = ""
	attached = false
	remaining = 0 if initial_available else cooldown_s
	refresh_eligibility()

func reset_attempt() -> void:
	reset_availability()
	struck = 0

func refresh_eligibility() -> void:
	var available := hook_session.is_empty() and remaining <= 0
	collision_layer = 8 if available else 0
	if available and not is_in_group(&"grapple_target"): add_to_group(&"grapple_target")
	if not available and is_in_group(&"grapple_target"): remove_from_group(&"grapple_target")

func hook_begin(ability: TraversalAbility, token: String) -> bool:
	if not hook_session.is_empty() or remaining > 0: return false
	holder = ability
	hook_session = token
	attached = false
	struck = 1.0
	refresh_eligibility()
	return true

func hook_arrive(token: String) -> void:
	if token == hook_session: attached = true

func hook_end(token: String) -> void:
	if token != hook_session or token.is_empty(): return
	hook_session = ""
	holder = null
	attached = false
	remaining = cooldown_s
	refresh_eligibility()

func eligibility_state() -> Dictionary:
	return {"session":hook_session,"remaining":remaining,"attached":attached}

func restore_eligibility(data: Dictionary) -> void:
	var recorded := str(data.get("session",""))
	if recorded.is_empty() or not is_instance_valid(holder) or holder.hook_target != self or hook_session != recorded:
		if is_instance_valid(holder) and holder.hook_target == self: holder.cancel()
		holder = null
		hook_session = ""
		attached = false
		remaining = float(data.get("remaining",0)) if recorded.is_empty() else cooldown_s
	else:
		attached = bool(data.attached)
	refresh_eligibility()

func _physics_process(delta: float) -> void:
	if remaining > 0:
		remaining = maxf(0,remaining-delta)
		if remaining == 0: refresh_eligibility()

func _process(delta: float) -> void:
	clock += delta
	struck = maxf(0,struck-delta*3)
	artwork.rotation = sin(clock*1.7)*.025+sin(struck*TAU*2)*struck*.08
	var glow := 1.0
	if remaining > 0:
		glow = 0.35
		if remaining <= minf(cooldown_s,reactivate_warning_s): glow += 0.24 * absf(sin(clock*22))
	artwork.modulate = Color(glow,glow,glow).lerp(Color(1.25,1.2,1.05),struck*.5)
	queue_redraw()

func hook_feedback() -> void:
	struck = 1.0

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var depth := Color.WHITE if remaining <= 0 else Color("68646a")
	var bracket := Vector2(0,-14) if hang_enabled else Vector2(0,10)
	MechanismRegionArt.stamp(self,"mount",bracket,Vector2(26,16),depth)
	if hang_enabled:
		TraversalMechanismArt.chain(self,bracket+Vector2(0,-2),Vector2(0,-7),3)
	else:
		MechanismRegionArt.stamp(self,"finial",Vector2(0,-18),Vector2(14,12),depth)
	var color := Color("ffd790") if remaining <= 0 else Color("57525a")
	if remaining > 0 and remaining < reactivate_warning_s: color = color.lerp(Color("ffd790"),absf(sin(clock*12)))
	for side: int in [-1,1]:
		var pin := Vector2(side*10,0)
		draw_rect(Rect2(pin-Vector2(2,2),Vector2(4,4)),Color("302e32"))
		draw_rect(Rect2(pin-Vector2.ONE,Vector2(2,2)),color)
	if struck <= 0: return
	for i: int in 5:
		var direction := Vector2.from_angle(float(i)*TAU/5)
		draw_rect(Rect2((direction*(12+(1-struck)*13)).round(),Vector2(2,2)),Color(1,.83,.45,struck))


func element_state() -> Dictionary:
	return {"phase":"available" if hook_session.is_empty() and remaining <= 0 else "in_use" if not hook_session.is_empty() else "cooldown","eligibility":eligibility_state()}

func element_restore(data: Dictionary) -> void:
	restore_eligibility(data.eligibility)
