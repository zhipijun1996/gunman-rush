class_name ActorResourceSnapshot
extends RefCounted

enum Kind { HEALTH, STAMINA }
var kind: Kind
var epoch: int
var current: float
var capacity: float
var terminal: bool

func copy() -> ActorResourceSnapshot:
	var result := ActorResourceSnapshot.new()
	result.kind = kind
	result.epoch = epoch
	result.current = current
	result.capacity = capacity
	result.terminal = terminal
	return result
