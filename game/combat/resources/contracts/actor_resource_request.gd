class_name ActorResourceRequest
extends RefCounted

# A local resource instance owns receipts. Future DamagePolicy supplies this request
# only after its Run/Stage/Actor eligibility checks, not directly from a hazard.
var event_id: StringName
var expected_epoch: int
var expected_instance_id: int
var amount: float

func _init(id: StringName = &"", epoch: int = -1, value: float = 0.0, instance_id: int = -1) -> void:
	event_id = id
	expected_epoch = epoch
	amount = value
	expected_instance_id = instance_id
