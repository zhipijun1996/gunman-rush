extends Node
## Initialize a displacement observer after AnimatableBody's first native sync.
## Only the observer's previous sample changes, never any body transform.
var observed: Array=[]
var samples:=0
func _ready() -> void:process_physics_priority=-90
func _physics_process(_delta: float) -> void:
	for support in observed:support.previous_platform=support.platform.global_position
	samples+=1
	if samples>=2:set_physics_process(false)
