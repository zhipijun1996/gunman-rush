class_name DemoToken
extends RefCounted

var run_epoch := 1
var stage_epoch := 1
var actor_epoch := 1

func copy() -> DemoToken:
	var result := DemoToken.new()
	result.run_epoch = run_epoch
	result.stage_epoch = stage_epoch
	result.actor_epoch = actor_epoch
	return result

func key() -> String:
	return "%d/%d/%d" % [run_epoch, stage_epoch, actor_epoch]
