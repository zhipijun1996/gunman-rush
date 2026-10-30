extends RefCounted
## Original ShotLatch and all actual bodies move as a child of the carrier.
## No player transform, platform trajectory or resource writes.
static func install(owner, data: Dictionary) -> void:
	for spec: Dictionary in data.get("latches",[]):
		if not spec.has("carrier_mount"):continue
		for latch: ShotLatch in owner.cells.latches:
			if str(latch.link_id)!=str(spec.id):continue
			for carrier: ModuleMovingPlatform in owner.context.module.moving_platforms:
				if str(carrier.definition.platform_id)==str(spec.carrier_mount):
					latch.reparent(carrier,true)
static func snapshot(owner) -> Array:
	var values: Array=[]
	for latch: ShotLatch in owner.cells.latches:
		var carrier:=latch.get_parent() as ModuleMovingPlatform
		if carrier==null:continue
		var at:=latch.bell_body.global_position
		var offset:=at-carrier.global_position
		values.append({"id":latch.link_id,"carrier_id":str(carrier.definition.platform_id),"receiver_global":[at.x,at.y],"carrier_global":[carrier.global_position.x,carrier.global_position.y],"receiver_offset":[offset.x,offset.y],"real_receiver_child_of_carrier":true})
	return values
