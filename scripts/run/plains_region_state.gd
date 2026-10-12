class_name PlainsRegionState
extends RefCounted
## Run-local instance ledger. Detached JSON snapshot supports world unload/reload;
## permanent notes still belong exclusively to MetaSaveService.
var manifest_hash := ""
var claimed: Dictionary = {}
var opened: Dictionary = {}
var visited: Dictionary = {}
var explored: Dictionary = {}
var actors: Dictionary = {}
var clocks: Dictionary = {}
var drops: Dictionary = {}
var mechanisms: Dictionary = {}
var boss_state: Dictionary = {}

func bind_map(hash_value: String) -> bool:
	if manifest_hash.is_empty(): manifest_hash = hash_value
	return manifest_hash == hash_value

func snapshot() -> Dictionary:
	return {"version": 2, "explored":explored.duplicate(true), "manifest_hash": manifest_hash, "claimed": claimed.duplicate(true), "opened": opened.duplicate(true), "visited": visited.duplicate(true), "actors": actors.duplicate(true), "clocks": clocks.duplicate(true), "drops": drops.duplicate(true), "mechanisms": mechanisms.duplicate(true), "boss_state": boss_state.duplicate(true)}

func restore(data: Dictionary, expected_hash: String) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2) or data.get("manifest_hash") != expected_hash: return false
	for key: String in ["claimed", "opened", "visited", "actors", "clocks", "drops", "mechanisms", "boss_state"]:
		if not data.get(key) is Dictionary: return false
	if data.get("version")==2 and not data.get("explored") is Dictionary: return false
	for key: Variant in data.get("explored",{}):
		if not key is String or data.explored[key]!=true: return false
		var coords: PackedStringArray=key.split(":")
		if coords.size()!=2 or not coords[0].is_valid_int() or not coords[1].is_valid_int(): return false
	explored=data.get("explored",{}).duplicate(true)
	manifest_hash = expected_hash
	claimed = data.claimed.duplicate(true)
	opened = data.opened.duplicate(true)
	visited = data.visited.duplicate(true)
	actors = data.actors.duplicate(true)
	clocks = data.clocks.duplicate(true)
	drops = data.drops.duplicate(true)
	mechanisms = data.mechanisms.duplicate(true)
	boss_state = data.boss_state.duplicate(true)
	return true
