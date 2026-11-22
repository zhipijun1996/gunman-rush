class_name WorldResourcePickup
extends Node2D
## A permanent room-authored, directly collectible resource.
@export_enum("note","health","time_energy","resonance") var resource_kind := "note"
@export var amount := 1.0
var session: OrdinaryRoomSession
var receipt := ""

func bind(host: OrdinaryRoomSession) -> void:
	session = host
	receipt = "pickup/%s/%s" % [host.room.room_id,get_meta("editor_entity_id")]
	host.state.committed.connect(refresh)
	refresh()

func refresh(_revision: int = 0) -> void:
	visible = not session.state.value.receipts.has(receipt)

func _physics_process(_delta: float) -> void:
	if session == null or not visible or not session.lifetime.active or session.controller.has_pending_damage(): return
	var actor := session.controller
	var reach := maxf(float(session.drop_rules.coin_pickup_radius),session.equipment.p("B01","radius"))
	if global_position.distance_to(session.player.global_position) > reach: return
	if not session.equipment.scene.clear_line(session.player.global_position,global_position): return
	var next := session.state.candidate()
	match resource_kind:
		"note": next.inventory["notes"] = int(next.inventory.get("notes",0)) + int(amount)
		"health":
			var hp := actor.actor_resources.health
			if hp.terminal or hp.normal_healing_blocked or hp.current >= hp.capacity: return
			next.hp = minf(hp.capacity,hp.current + amount)
		"time_energy":
			var stamina := actor.actor_resources.stamina
			if stamina.current >= stamina.capacity: return
			next.services.effects.stamina = minf(stamina.capacity,stamina.current + amount)
		"resonance":
			if actor.combat_energy.current >= actor.combat_energy.capacity(): return
			next.combat_energy = minf(actor.combat_energy.capacity(),actor.combat_energy.current + amount)
		_: return
	next.receipts[receipt] = {"source":receipt,"source_hash":resource_kind.sha256_text(),"revision":session.state.revision+1}
	if session.state.commit(next,session.state.revision):
		session.equipment.sync_resources(true)
		actor.actor_resources.stamina.restore_value(next.services.effects.stamina)
		GameAudio.cue(self,&"coin")

func _draw() -> void:
	var color: Color = {"note":Color.GOLD,"health":Color.INDIAN_RED,"time_energy":Color.SKY_BLUE,"resonance":Color.AQUAMARINE}[resource_kind]
	draw_circle(Vector2.ZERO,6,color)
	draw_arc(Vector2.ZERO,9,0,TAU,12,color,1)
