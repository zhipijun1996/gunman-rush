class_name LevelRuntime
extends RefCounted
## Actual shared content assembly. No generator, Manifest, RNG or run services.
static func assemble(parent: Node2D, plan: LevelPlan, state: PlainsRegionState, presentation: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return {"ok":false,"error":"Level parent must be in the scene tree","assembler":null}
	if state==null: return {"ok":false,"error":"Missing map state","assembler":null}
	if plan==null: return {"ok":false,"error":"Missing level plan","assembler":null}
	var error := plan.validation_error()
	if not error.is_empty(): return {"ok":false,"error":error,"assembler":null}
	var assembler: PlainsRegionAssembler = ThornForestRegionAssembler.new() if plan.forest!=null else PlainsRegionAssembler.new()
	assembler.region_state=state
	parent.add_child(assembler)
	var result := assembler.build_plan(plan,presentation)
	result.assembler=assembler
	return result

static func install_modules(parent: Node2D, plan: LevelPlan, state: PlainsRegionState) -> Array[PlatformingModule]:
	var modules: Array[PlatformingModule] = []
	for placement: LevelModulePlacement in plan.modules:
		var module := PlatformingModule.new()
		module.name=placement.instance_id.replace("/","_")
		module.definition=placement.definition.duplicate(true) as PlatformingModuleDefinition
		module.position=placement.position
		module.authoring_debug=false
		if state!=null: module.clock=float(state.clocks.get(placement.instance_id,0.0))
		modules.append(module)
		parent.add_child(module)
	return modules

static func create_actor(placement: Dictionary) -> EnemyMotor:
	var actor := EnemyFactory.create_for_behavior(StringName(placement.behavior_id),placement.overrides)
	if actor!=null: actor.position=placement.position
	return actor

static func create_boss(placement: Dictionary) -> BossMotor:
	if placement.is_empty(): return null
	var boss := BossFactory.create(StringName(placement.definition_id))
	if boss!=null: boss.position=placement.position
	return boss

static func restore_pickups(records: Array[Dictionary], claims: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in records:
		result.append({"id":row.id,"kind":row.kind,"amount":int(row.amount),"position":row.position,"claimed":claims.has(row.id)})
	return result

static func restore_caches(records: Array[Dictionary], claims: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in records:
		var chest := row.duplicate(true)
		chest.claimed=claims.has(chest.id)
		result.append(chest)
	return result

static func rect(row: Array) -> Rect2:
	return Rect2(row[0],row[1],row[2],row[3])
