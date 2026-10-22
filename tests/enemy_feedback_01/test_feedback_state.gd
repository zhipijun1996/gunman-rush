extends SceneTree
## Isolated health-resource boundary tests; never used as combat/movie evidence.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("FAIL: ",label)
func request(health: HealthState, id: StringName, amount: float) -> ActorResourceRequest:
	return ActorResourceRequest.new(id,health.epoch,amount,health.get_instance_id())
func run() -> void:
	var health := HealthState.new()
	var definition := load("res://resources/enemies/patrol_health.tres") as HealthDefinition
	check(health.configure(definition),"real health definition configures")
	var feedback := load("res://resources/damage/feedback.tres") as DamageFeedbackDefinition
	var state := EnemyFeedback01State.new();state.bind(health,feedback)
	check(state.hurt_count==0 and not state.death_started,"initial bind never presents damage")
	var first := request(health,&"first",1)
	check(health.apply_damage(first).status==ActorResourceResult.Status.APPLIED,"valid transaction applies")
	check(state.hurt_count==1 and state.hurt_remaining==feedback.hurt_seconds,"one hurt uses existing feedback duration")
	check(health.apply_damage(first).status==ActorResourceResult.Status.REPLAY and state.hurt_count==1,"retry never restarts hurt")
	var age := state.hurt_remaining;health.heal(request(health,&"heal",1))
	check(state.hurt_count==1 and state.hurt_remaining==age,"healing cannot trigger or refresh hurt")
	state.advance(feedback.hurt_seconds)
	check(state.pose(Vector2(.7,1.1),Vector2(1.1,.5))==Vector2.ONE,"hurt returns exactly to neutral")
	# set_max can reduce HP and emit a negative amount; it is not a damage hit.
	health.set_max(request(health,&"clip_capacity",2))
	check(state.hurt_count==1 and state.death_count==0,"capacity clipping is not hurt")
	var stale := request(health,&"old_epoch",1)
	check(health.configure(definition),"initialize advances health epoch")
	check(health.apply_damage(stale).status==ActorResourceResult.Status.STALE and state.hurt_remaining==0,"old epoch refused without effect")
	check(health.apply_damage(request(health,&"first",1)).status==ActorResourceResult.Status.APPLIED and state.hurt_count==2,"new epoch may legitimately reuse event id")
	var lethal := request(health,&"lethal",2);health.apply_damage(lethal)
	check(state.death_count==1 and state.hurt_count==2 and state.hurt_remaining==0,"lethal damage interrupts hurt with one death")
	health.apply_damage(lethal)
	check(state.death_count==1,"terminal retry cannot replay death")
	state.advance(feedback.hurt_seconds*2)
	check(not state.receipt().death_active,"death local response is bounded by existing duration")
	var terminal := definition.duplicate(true) as HealthDefinition;terminal.initial_current=0
	health.configure(terminal)
	check(not state.death_started and state.death_count==1,"terminal restore clears transient without new death")
	var restored := EnemyFeedback01State.new();restored.bind(health,feedback)
	check(not restored.death_started and restored.death_count==0,"new presentation bound to corpse never replays")
	restored.dispose();state.dispose()
	check(health.changed.get_connections().is_empty(),"unload disconnects both self-owned subscriptions")
	health.configure(definition);health.apply_damage(request(health,&"after_unload",1))
	check(state.hurt_count==2 and state.hurt_remaining==0,"detached presentation receives no late effect")
	print("ENEMY_FEEDBACK_STATE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
