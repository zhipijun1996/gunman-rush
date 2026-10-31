class_name LevelBuildResult
extends RefCounted
var plan: LevelPlan
var error := ""
# Optional source-owned compatibility data for the existing region views and
# RunManifest writer. LevelRuntime never reads it; new providers may omit it.
var legacy_generated: Dictionary = {}
var resolved_capabilities: Dictionary = {}

func accepted() -> bool:
	return plan!=null and error.is_empty()
