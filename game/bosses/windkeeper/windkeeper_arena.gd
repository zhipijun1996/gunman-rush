class_name WindkeeperArena
extends Node
## Stage III grows readable thorns from the intact floor; death retracts them.
var module: PlatformingModule
var encounter: WindkeeperEncounter
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var segment: SegmentRespawn
var thorns_active := false
var _contact: DemoContactEmitter
var _art: WorldSpikeArt
var _age := 0.0
var _growth := 0.0
var _floor: Rect2
var _band: Rect2
var _stands: Array[Vector2] = []

func setup(owner_module: PlatformingModule, boss_encounter: WindkeeperEncounter, player_controller: PlayerController, damage_policy: FrameDamagePolicy, life: DemoLifetime, respawn: SegmentRespawn, _ground: PlainsGroundSupports = null) -> void:
	module = owner_module
	encounter = boss_encounter
	controller = player_controller
	policy = damage_policy
	lifetime = life
	segment = respawn
	_floor = module.global_transform * module.definition.platforms[0]
	var config := encounter.definition as WindkeeperDefinition
	_band = Rect2(_floor.position + Vector2(config.thorn_edge_margin, -config.thorn_height), Vector2(_floor.size.x - config.thorn_edge_margin * 2, config.thorn_height))
	_contact = DemoContactEmitter.environment_rect(_band, policy, controller, &"windkeeper_floor_thorns")
	_contact.top_level = true
	_contact.enabled = false
	add_child(_contact)
	_art = WorldSpikeArt.new()
	_art.top_level = true
	add_child(_art)
	_art.setup([{"bounds": [_band.position.x, _band.position.y, _band.size.x, _band.size.y], "facing": "up"}], [_floor])
	_art.z_index = -1 # Intact floor masks the roots while the tips grow upwards.
	_art.hide()
	for i: int in module.definition.one_way_platform_indices:
		var slab: Rect2 = module.definition.platforms[i]
		var stand := module.to_global(Vector2(slab.get_center().x, slab.position.y - 18))
		_stands.append(stand)
		segment.add_anchor(StringName("windkeeper_perch_%s" % (_stands.size()-1)), stand)
	encounter.phase_changed.connect(_phase_changed)
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, shot_id: int) -> void: encounter.register_rune_shot(controller.session_id, shot_id))

func _phase_changed(phase: int) -> void:
	if phase == 3: restore_floor_thorns()

func restore_floor_thorns() -> void:
	if thorns_active or encounter.health.terminal or not lifetime.active: return
	thorns_active = true
	_age = 0.0
	segment.danger_bounds.append(_band)
	# An initial safe perch is needed if the warning begins while on the floor.
	var closest := 0
	for i: int in _stands.size():
		if absf(_stands[i].x-controller.motor.global_position.x) < absf(_stands[closest].x-controller.motor.global_position.x): closest = i
	segment.activate_anchor(StringName("windkeeper_perch_%s" % closest))
	GameAudio.cue(module, &"warning")

func _physics_process(delta: float) -> void:
	if not lifetime.active:
		_contact.enabled = false
		_art.hide()
		return
	var config := encounter.definition as WindkeeperDefinition
	if encounter.health.terminal:
		_contact.enabled = false
		thorns_active = false
		segment.danger_bounds.erase(_band)
		_growth = move_toward(_growth, 0, delta / config.thorn_growth_seconds)
	elif thorns_active:
		_age += delta
		# Small visible buds precede growth; damage starts only at full height.
		_growth = .35 if _age < config.thorn_warning_seconds else lerpf(.35, 1.0, clampf((_age-config.thorn_warning_seconds)/config.thorn_growth_seconds, 0, 1))
		_contact.enabled = _growth >= 1.0
	_art.visible = _growth > 0
	_art.position.y = (1.0-_growth)*config.thorn_height
	if not controller.active or not controller.motor.is_on_floor(): return
	if config.platform_trials and encounter.stage_phase == 3: encounter.rune_platform = -1
	for i: int in _stands.size():
		var slab: Rect2 = module.global_transform * module.definition.platforms[module.definition.one_way_platform_indices[i]]
		var feet := controller.motor.global_position + Vector2(0,18)
		if absf(feet.y-slab.position.y)<2 and feet.x-12>=slab.position.x and feet.x+12<=slab.end.x:
			if thorns_active: segment.activate_anchor(StringName("windkeeper_perch_%s" % i))
			if config.platform_trials and encounter.stage_phase == 3: encounter.rune_platform = i
