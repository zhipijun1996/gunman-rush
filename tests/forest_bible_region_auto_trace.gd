extends "res://tests/forest_depth_region_trace.gd"
## v15 hooks preserve the original trace's complete route/strategy behavior.
const BIBLE_SUPPORT := preload("res://tests/forest_bible_trace_support.gd")

func canopy_layout() -> bool:
	return BIBLE_SUPPORT.qualifies(self) or super.canopy_layout()
func interwoven_layout() -> bool:
	return BIBLE_SUPPORT.qualifies(self) or super.interwoven_layout()
func woven_layout() -> bool:
	return BIBLE_SUPPORT.qualifies(self) or super.woven_layout()

func begin() -> void:
	BIBLE_SUPPORT.install(self)
	await super.begin()
	BIBLE_SUPPORT.bind(self)

func observe_actual_projectile(serial: int) -> void:
	super.observe_actual_projectile(serial)
	BIBLE_SUPPORT.observe_actual_projectile(self,serial)

func _process(delta: float) -> void:
	BIBLE_SUPPORT.process_reader(self)
	super._process(delta)

func admission_evidence() -> Dictionary:
	return BIBLE_SUPPORT.admission_evidence(self)
