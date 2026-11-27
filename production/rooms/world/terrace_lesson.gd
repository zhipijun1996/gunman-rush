extends Node
## Observe the authored recoil trial. Gameplay and the ordinary camera stay live.
const CHIME := preload("res://rooms/world/p02_chime.gdshader")
var host: Node
var session: OrdinaryRoomSession
var config: Dictionary
var entities: Dictionary
var bell_mount: Sprite2D
var grounded_on_west := false
var west_jump := false
var west_recoil := false
var was_airborne := false
var chime_time := 0.0
var hint_remaining := 0.0

func install(owner_node: Node, doc: Dictionary) -> void:
	host = owner_node
	session = host.active
	config = doc.scenery.terrace_lesson
	entities = doc.entities
	bell_mount = session.room_dressing.get_node(NodePath(config.bell))
	var material := ShaderMaterial.new()
	material.shader = CHIME
	bell_mount.material = material
	session.controller.jump_ability.accepted_jump.connect(_jumped)
	session.controller.shoot_ability.shot_fired.connect(_shot)
	session.add_child(self)

func _process(delta: float) -> void:
	chime_time = maxf(0.0,chime_time-delta)
	bell_mount.material.set_shader_parameter("age",1.0-chime_time)

func _jumped(kind: StringName, _serial: int, _center: Vector2) -> void:
	if kind==&"ground":
		west_jump = grounded_on_west
		west_recoil = false

func _shot(direction: Vector2, _packet: int) -> void:
	if west_jump and not session.player.is_on_floor() and direction.x<-.1:
		west_recoil = true

func update_field(delta: float) -> void:
	var at := session.player.position
	var west := FixedWorldProvider.rect(entities[config.takeoffs[0]].properties.rect)
	var basin := FixedWorldProvider.rect(entities[config.retry_floor].properties.rect)
	var pier := FixedWorldProvider.rect(entities[config.landing].properties.rect)
	var cap := FixedWorldProvider.rect(entities[config.cap].properties.rect)
	var floor_contact := session.player.is_on_floor()
	var feet := at+Vector2.DOWN*18
	hint_remaining = maxf(0.0,hint_remaining-delta)
	if floor_contact:
		grounded_on_west = false
		for id: String in config.takeoffs:
			var tread := FixedWorldProvider.rect(entities[id].properties.rect)
			if feet.x>=tread.position.x-10 and feet.x<=tread.end.x+10 and absf(feet.y-tread.position.y)<3:
				grounded_on_west = true
				break
	if was_airborne and floor_contact:
		if not host.lesson_progress.has("landed") and not host.lesson_progress.has("hint") and feet.x>west.end.x and feet.x<basin.end.x and absf(feet.y-basin.position.y)<4:
			host.lesson_progress["hint"] = true
			host.notice.text = "回到田埂，跳起后朝身后偏下开枪。"
			hint_remaining = 3.4
		if west_recoil and not host.lesson_progress.has("landed") and feet.x>=pier.position.x and feet.x<=cap.end.x and absf(feet.y-pier.position.y)<4:
			host.lesson_progress["landed"] = true
			chime_time = 1.0
			GameAudio.cue(bell_mount,&"mechanism_bell")
		west_jump = false
		west_recoil = false
	was_airborne = not floor_contact
	if host.issue_remaining>0: return
	host.notice.visible = hint_remaining>0
	host.notice.modulate.a = clampf(hint_remaining/.4,0,1)
