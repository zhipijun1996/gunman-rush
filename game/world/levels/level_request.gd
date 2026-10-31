class_name LevelRequest
extends RefCounted
## Value inputs only. No App, Session, wallet, player or callback bag.
var root_seed := ""
var region_id: StringName = &"plains"
var map_index := 1
var tuning: PlayerTuning
var expected_hash := ""
var root_bell_mode := "legacy_v10"
var capabilities: Dictionary = {}
