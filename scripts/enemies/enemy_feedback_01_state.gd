class_name EnemyFeedback01State
extends RefCounted
## Presentation-only accepted-health clock. No Actor/AI/scene/audio dependencies.
var hurt_remaining := 0.0
var death_age := 0.0
var death_started := false
var hurt_count := 0
var death_count := 0
var _health: HealthState
var _feedback: DamageFeedbackDefinition
var _epoch := 0
var _events: Dictionary = {}

func bind(health: HealthState, feedback: DamageFeedbackDefinition) -> void:
	dispose()
	_health=health;_feedback=feedback;_epoch=health.epoch
	clear_transient()
	health.changed.connect(_changed)

func dispose() -> void:
	if _health!=null and _health.changed.is_connected(_changed): _health.changed.disconnect(_changed)
	_health=null
	clear_transient()

func clear_transient() -> void:
	hurt_remaining=0;death_age=0;death_started=false;_events.clear()

func _changed(result: ActorResourceResult) -> void:
	if result==null or result.snapshot==null or _health==null: return
	if result.operation==&"initialize":
		_epoch=_health.epoch;clear_transient();return
	if result.status!=ActorResourceResult.Status.APPLIED or result.operation!=&"damage" or result.amount_applied>=0: return
	if result.snapshot.epoch!=_epoch or _health.epoch!=_epoch or result.event_id.is_empty() or _events.has(result.event_id): return
	_events[result.event_id]=true
	if result.snapshot.terminal:
		if death_started: return
		death_started=true;death_age=0;hurt_remaining=0;death_count+=1
	else:
		hurt_remaining=_feedback.hurt_seconds;hurt_count+=1

func advance(delta: float) -> void:
	hurt_remaining=maxf(0,hurt_remaining-delta)
	if death_started: death_age=minf(_feedback.hurt_seconds,death_age+delta)

func pose(hurt_pose: Vector2, terminal_pose: Vector2) -> Vector2:
	if death_started:
		var progress := clampf(death_age/maxf(_feedback.hurt_seconds,.001),0,1)
		return Vector2.ONE.lerp(terminal_pose,1-pow(1-progress,3))
	if hurt_remaining<=0: return Vector2.ONE
	var progress := 1-hurt_remaining/maxf(_feedback.hurt_seconds,.001)
	# Fast compression, small opposing recovery, then exactly the original pose.
	var pulse := sin(progress*PI*2)*exp(-progress*3)
	return Vector2.ONE+(hurt_pose-Vector2.ONE)*pulse

func receipt() -> Dictionary:
	return {"epoch":_epoch,"hurt_count":hurt_count,"death_count":death_count,"hurt_remaining":hurt_remaining,"death_age":death_age,"death_active":death_started and death_age<_feedback.hurt_seconds}
