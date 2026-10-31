class_name ItemTimeContext
extends RefCounted
## The time family receives only these capabilities, never the whole runtime.
## This boundary intentionally excludes inventory/build/wallet access, damage,
## active casting and target selection. Add capabilities only for a real time
## consumer; do not mirror the runtime API here. No state authority is copied.
var _runtime: WeakRef
var _retained_runtime: RefCounted

func _init(runtime: RefCounted) -> void:
	_runtime = weakref(runtime)

# The old time methods held a local owner reference across synchronous resource
# callbacks. Retain it for exactly that call, without exposing the owner or
# introducing a persistent Runtime -> family -> Runtime reference cycle.
func scoped() -> ItemTimeContext:
	var runtime := _runtime.get_ref() as RefCounted
	if runtime == null: return null
	var context := ItemTimeContext.new(runtime)
	context._retained_runtime = runtime
	return context

func actor() -> PlayerController:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime.call("actor") as PlayerController if runtime != null else null

func world_root() -> Node:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime.call("world_root") as Node if runtime != null else null

func is_live() -> bool:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime != null and bool(runtime.call("is_live"))

func effect(id: StringName) -> Dictionary:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime.call("effect", id) as Dictionary if runtime != null else {}

func state(id: StringName) -> Dictionary:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime.call("state", id) as Dictionary if runtime != null else {}

func patch_state(id: StringName, patch: Dictionary, receipt: StringName) -> bool:
	var runtime := _runtime.get_ref() as RefCounted
	return runtime != null and bool(runtime.call("patch_state", id, patch, receipt))

func cue(kind: StringName, point: Vector2, detail: Dictionary) -> void:
	var runtime := _runtime.get_ref() as RefCounted
	if runtime != null: runtime.call("cue", kind, point, detail)
