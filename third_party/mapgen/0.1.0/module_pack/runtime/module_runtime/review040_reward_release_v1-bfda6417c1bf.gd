extends RefCounted
## Release only after the original reward service accepts its real transaction.
var spec: Dictionary
var body: StaticBody2D
var rewards
var released:=false
var claim_frame:=-1
var release_frame:=-1
func configure(data: Dictionary, support: StaticBody2D, service) -> void:
	spec=data;body=support;rewards=service
func step(frame: int) -> void:
	if released:return
	for event: Dictionary in rewards.events:
		if event.get("type","")!="chest_claim" or str(event.get("id",""))!=str(spec.reward_id) or not event.get("accepted",false):continue
		if not rewards.services.has(str(spec.reward_id)) or not rewards.services[str(spec.reward_id)].claimed:return
		claim_frame=int(event.frame);release_frame=frame;body.collision_layer=0;body.collision_mask=0;released=true
		return
func snapshot() -> Dictionary:
	return {"released":released,"claim_frame":claim_frame,"release_frame":release_frame,"reward_id":spec.reward_id,"support_collision_layer":body.collision_layer,"transaction_service":"original SimpleRoomReward"}
