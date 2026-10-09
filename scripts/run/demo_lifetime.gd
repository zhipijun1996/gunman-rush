class_name DemoLifetime
extends RefCounted

var epoch := 1
var stage_epoch := 1
var actor_epoch := 1
var active := true

func token() -> DemoToken:
	var result := DemoToken.new()
	result.run_epoch = epoch
	result.stage_epoch = stage_epoch
	result.actor_epoch = actor_epoch
	return result

func accepts(value: DemoToken) -> bool:
	return active and value != null and value.run_epoch == epoch and value.stage_epoch == stage_epoch and value.actor_epoch == actor_epoch

func invalidate_actor() -> void:
	actor_epoch += 1

func end() -> void:
	if active:
		active = false
		epoch += 1
		stage_epoch += 1
		actor_epoch += 1
