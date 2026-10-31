class_name ShotEnergyPolicy
extends RefCounted
## Formal shot economy. Legacy fixtures retain their separate focus prototype.
signal recovered(amount: float, airborne: bool)
var controller: PlayerController
var definition: ShotEnergyDefinition
var shot_energy_cost := 0.0
var hit_energy_recovery := 0.0
var ground_energy_recovery := 0.0
var shot_energy_delay := 0.0
var _delay := 0.0
var _hits: Dictionary = {}

func configure(actor: PlayerController, config: ShotEnergyDefinition) -> bool:
	if config==null or not config.is_valid(): return false
	controller=actor
	definition=config
	shot_energy_cost=config.shot_energy_cost
	hit_energy_recovery=config.hit_energy_recovery
	ground_energy_recovery=config.ground_recovery
	shot_energy_delay=config.recovery_delay
	if config.shooting_consumes_energy:
		return actor.actor_resources.stamina.configure(config)
	# AirFocus is the sole owner of time-energy consumption and regeneration.
	return true

func can_fire() -> bool:
	return is_instance_valid(controller) and controller.active and not controller.actor_resources.health.terminal and (not definition.shooting_consumes_energy or controller.actor_resources.stamina.current+1e-9>=shot_energy_cost)

func consume(shot_id: int) -> bool:
	if not can_fire(): return false
	if not definition.shooting_consumes_energy: return true
	var state:=controller.actor_resources.stamina
	var event:=StringName("shot/%s/%s" % [controller.session_id,shot_id])
	var result:=state.try_consume(ActorResourceRequest.new(event,state.epoch,shot_energy_cost,state.get_instance_id()))
	if result.status!=ActorResourceResult.Status.APPLIED: return false
	_delay=shot_energy_delay
	return true

func advance(delta: float, grounded: bool) -> void:
	if not definition.shooting_consumes_energy: return
	if not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or not is_finite(delta) or delta<=0: return
	var recovery_delta:=maxf(0.0,delta-_delay)
	_delay=maxf(0.0,_delay-delta)
	if grounded and recovery_delta>0:
		var state:=controller.actor_resources.stamina
		state.grant_continuous(ground_energy_recovery*recovery_delta,state.epoch)

func on_hit(expected_session: int, shot_id: int, airborne: bool) -> void:
	if not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id!=expected_session: return
	var key:="%s/%s" % [expected_session,shot_id]
	if _hits.has(key): return
	_hits[key]=true
	if not definition.shooting_consumes_energy:
		# Committed airborne damage still returns a round, without touching time.
		if airborne: controller.queue_grant(1,expected_session)
		return
	var state:=controller.actor_resources.stamina
	var result:=state.grant(ActorResourceRequest.new(StringName("hit/"+key),state.epoch,hit_energy_recovery,state.get_instance_id()))
	if result.status!=ActorResourceResult.Status.APPLIED: return
	# The committed hit returns one round, never extra jumps or a larger cap.
	if airborne: controller.queue_grant(1,expected_session)
	recovered.emit(result.amount_applied,airborne)
