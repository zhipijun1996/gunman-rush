@static_unload
class_name BossRoarTimeline
extends RefCounted
## Read-only presentation phases on the existing encounter intro clock.
const RELEASE := .30
const SETTLE := .82

static func breath(t: float) -> float:
	return smoothstep(0,.23,t)*(1-smoothstep(.25,.36,t))

static func strength(t: float) -> float:
	return smoothstep(.28,.34,t)*(1-smoothstep(SETTLE,1,t))

static func burst(t: float) -> float:
	return exp(-pow((t-.335)*27,2))
