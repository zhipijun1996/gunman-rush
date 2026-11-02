class_name ForestDirectionalGeometry
extends RefCounted
## Data only: shared forest platform/anchor schema, adapted to the existing module consumer.
const VERSION := "forest-directional-golden-v1"
static func build() -> Dictionary:
	return {"version":VERSION,"id":"root_arch_hook_recoil","spawn":[0.0,0.0],"goal":[550.0,-240.0],"world_bounds":[-320.0,-550.0,1220.0,850.0],
		"platforms":[{"id":"entry","rect":[-220.0,18.0,300.0,60.0],"one_way":false},{"id":"root_arch","rect":[-220.0,-520.0,570.0,410.0],"one_way":false},{"id":"crown","rect":[500.0,-222.0,260.0,24.0],"one_way":false},{"id":"recovery","rect":[-310.0,220.0,1190.0,40.0],"one_way":false},{"id":"recovery_step","rect":[-305.0,118.0,65.0,20.0],"one_way":true}],
		"hook_anchors":[{"id":"side_ring","position":[200.0,-40.0]},{"id":"arch_exit_ring","position":[470.0,-130.0]},{"id":"crown_ring","position":[500.0,-320.0]},{"id":"return_catch_ring","position":[415.0,-40.0]}],
		"dangers":[[82.0,100.0,790.0,18.0]],
		"steps":[{"id":"side_catch","anchor_id":"side_ring","direction":"horizontal","then":"away_kick"},{"id":"root_exit","action":"shoot_left_recoil_right","then":"arch_exit_ring"},{"id":"crown_rise","anchor_id":"crown_ring","then":"stable_crown"}],
		"observations":[{"platform_id":"entry","see":["side_ring","root_arch"]},{"platform_id":"crown","see":["return_catch_ring","side_ring","return_drop"]}],
		"return":{"drop_outside_x":390.0,"cast_below_y":-70.0,"catch_anchor_id":"return_catch_ring","anchor_id":"side_ring","shoot_direction":[1.0,0.0],"goal_support":"entry"},
		"recovery":{"support":"recovery","walk_x":-275.0,"via":"recovery_step","exit":"entry"}}
## Separate phrase; the proven03 build above is kept intact for historical replay.
static func build_narrow() -> Dictionary:
	var data := build()
	data.version="forest-directional-narrow-thorns-v1"
	data.id="side_hook_thorn_mouth"
	data.goal=[355.0,-42.0]
	data.platforms[2]={"id":"crown","rect":[250.0,-24.0,320.0,60.0],"one_way":false}
	data.hook_anchors=[data.hook_anchors[0]]
	data.dangers=[[210.0,-138.0,60.0,44.0],[210.0,-24.0,60.0,52.0]]
	data.steps=[{"id":"side_catch","anchor_id":"side_ring","direction":"horizontal","then":"away_kick"},{"id":"thorn_mouth","action":"shoot_left_recoil_right","then":"stable_crown"}]
	data.observations=[{"platform_id":"entry","see":["side_ring","upper_thorns","lower_thorns","crown"]},{"platform_id":"crown","see":["right_drop","recovery"]}]
	data.return={"drop_outside_x":600.0,"via":"recovery","goal_support":"entry"}
	data.allowed_seams=[{"platform_id":"entry","side":"left","top":18.0},{"platform_id":"crown","side":"right","top":-24.0}]
	data.protected_bounds=data.world_bounds.duplicate()
	data.damage_mode="production_environment_policy"
	return data
static func as_module(data: Dictionary) -> PlatformingModuleDefinition:
	var definition := PlatformingModuleDefinition.new()
	definition.module_id=&"forest_directional_golden"
	definition.world_bounds=rect(data.world_bounds)
	for row: Dictionary in data.platforms:
		if row.one_way: definition.one_way_platform_indices.append(definition.platforms.size())
		definition.platforms.append(rect(row.rect))
	for danger: Array in data.dangers: definition.danger_bounds.append(rect(danger))
	definition.anchors=[point(data.spawn),point(data.goal)]
	definition.main_route=[0,1]
	definition.entry_port=PlatformingModulePort.new()
	definition.entry_port.port_id=&"root_entry"
	definition.entry_port.position=point(data.spawn)
	definition.exit_port=PlatformingModulePort.new()
	definition.exit_port.port_id=&"crown_exit"
	definition.exit_port.position=point(data.goal)
	return definition
static func point(value: Array) -> Vector2: return Vector2(value[0],value[1])
static func rect(value: Array) -> Rect2: return Rect2(value[0],value[1],value[2],value[3])
