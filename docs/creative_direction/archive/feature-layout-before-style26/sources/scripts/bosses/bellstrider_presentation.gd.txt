class_name BellstriderPresentation
extends Node2D
## Articulated carriage; all production style branches use this actual rig.
## Original PNGs are unchanged. No independent body/weakpoint animation clock.
const MACHINE := preload("res://assets/underworld_plains/actors/bellstrider.png")
const BELL := preload("res://assets/underworld_plains/actors/bell.png")
const AUDIO := preload("res://scripts/audio/bellstrider_audio.gd")
const INK := Color("24231e")
const SHADOW := Color("41372a")
const BRASS := Color("786044")
const EDGE := Color("a28456")
const MOSS := Color("4b5640")
@export var encounter: BellstriderEncounter
var pixel_style := false
var hit_template: EnemyHitTemplate
# Preserve accepted-event lifecycle; the old mesh deformation is never drawn.
var motion := BossMotionPresentation.new()
var _armour_point := Vector2(44, 8)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
	encounter.armour_hit.connect(_armour_impact)
	encounter.objective_changed.connect(_objective_changed)
	var service := AUDIO.new()
	service.name = "BellstriderAudio"
	add_child(service)
	service.bind(encounter)
	var arrival := BossArrivalPresentation.new()
	arrival.configure(encounter, self, true)
	get_parent().add_child.call_deferred(arrival)


func _objective_changed(_text: String) -> void:
	# Arrival alone offsets this CanvasItem while damage is disabled. Exiting or
	# skipping intro must settle immediately, before the bell becomes shootable.
	if encounter.mode != &"intro":
		position = Vector2.ZERO


func synchronize_presentation() -> void:
	# The complete region restore owns epoch replacement. Rebind once here,
	# without replaying any past cue; an unfinished saved death keeps only its
	# future mechanical-failure layers eligible.
	if not is_instance_valid(encounter):
		return
	motion.synchronize(encounter)
	_objective_changed("")
	var service := get_node_or_null("BellstriderAudio") as BellstriderAudio
	if service != null:
		service.bind(encounter, null, encounter.health.terminal)
	queue_redraw()


func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(encounter):
		return
	motion.sample(encounter, delta)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(encounter):
		return
	var pose: Dictionary = encounter.rig_pose()
	_draw_wake(pose)
	draw_set_transform_matrix(pose.mast_transform)
	_draw_mast(pose)
	draw_set_transform_matrix(pose.body_transform)
	_draw_suspension(pose)
	_draw_hull(pose)
	draw_set_transform_matrix(pose.launcher_transform)
	_draw_launcher(pose)
	_draw_wheel(pose.left_wheel, false)
	_draw_wheel(pose.right_wheel, true)
	draw_set_transform_matrix(pose.bell_transform)
	_draw_main_bell(pose)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_impacts(pose)
	_draw_loose_parts(pose)


func _draw_mast(pose: Dictionary) -> void:
	# Empty cage: no baked-in second bell and no central damage-core overlay.
	for side: float in [-1.0, 1.0]:
		var x := side * 32.0
		_poly(
			[Vector2(x - 5, 14), Vector2(x - 4, -94), Vector2(x + 2, -104), Vector2(x + 5, 14)], INK
		)
		_poly(
			[Vector2(x - 2, 10), Vector2(x - 2, -94), Vector2(x + 1, -98), Vector2(x + 2, 10)],
			BRASS
		)
		_line(Vector2(x - 2, -88), Vector2(x - 2, 2), EDGE, 1)
		_line(Vector2(x, -36), Vector2(side * 55, 15), INK, 7)
		_line(Vector2(x, -36), Vector2(side * 55, 15), BRASS, 3)
		_bolt(Vector2(x, -38), 3)
		_bolt(Vector2(x, -94), 2)
	# Source canopy/moss retain the existing patina, excluding the old main bell.
	draw_texture_rect_region(
		MACHINE, Rect2(-40, -125, 80, 28), Rect2(24, 3, 80, 28), Color(0.83, 0.83, 0.78)
	)
	draw_texture_rect_region(
		MACHINE, Rect2(-39, -99, 13, 34), Rect2(25, 34, 13, 34), Color(0.75, 0.83, 0.72)
	)
	draw_texture_rect_region(
		MACHINE, Rect2(26, -96, 12, 28), Rect2(84, 39, 12, 28), Color(0.74, 0.81, 0.70)
	)
	_line(Vector2(-30, -106), Vector2(31, -106), INK, 6)
	_line(Vector2(-30, -107), Vector2(31, -107), EDGE, 2)
	_bolt(Vector2(0, -106), 4)
	_line(Vector2(0, -106), Vector2(0, -100), Color("9f824e"), 2)
	_draw_gear(Vector2(-30, -23), 8, -float(pose.gear_angle), Color("6a5840"))


func _draw_suspension(pose: Dictionary) -> void:
	_line(Vector2(-55, 31), Vector2(55, 31), INK, 9)
	_line(Vector2(-55, 29), Vector2(55, 29), Color("645841"), 3)
	for side: float in [-1.0, 1.0]:
		var at := Vector2(side * 44, 24)
		_poly(
			[
				at + Vector2(-12, -9),
				at + Vector2(12, -9),
				at + Vector2(9, 13),
				at + Vector2(-9, 13)
			],
			SHADOW
		)
		for i: int in 4:
			_line(at + Vector2(-9, -5 + i * 4), at + Vector2(9, -3 + i * 4), Color("a18a60"), 2)
		_bolt(at + Vector2(0, -10), 4)
	# Hinged phase panels expose only small warm seams, away from the weak bell.
	for side: float in [-1.0, 1.0]:
		var hinge := Transform2D(side * float(pose.panel_angle), Vector2(side * 55, 6))
		var body: Transform2D = pose.body_transform
		draw_set_transform_matrix(body * hinge)
		_poly([Vector2(-9, -8), Vector2(9, -6), Vector2(11, 20), Vector2(-10, 19)], INK)
		_poly([Vector2(-7, -6), Vector2(7, -4), Vector2(8, 16), Vector2(-7, 16)], Color("65553e"))
		_line(Vector2(-6, -5), Vector2(6, -3), EDGE, 1)
		if float(pose.warm_light) > 0:
			_line(
				Vector2(-5, 4), Vector2(-5, 13), Color(Color("b07c3d"), float(pose.warm_light)), 1
			)
		draw_set_transform_matrix(body)


func _draw_hull(pose: Dictionary) -> void:
	# Roof y=-4, width140; upper bell has real clear air beneath its lip.
	_poly(BellstriderRigPose.HULL_POINTS, INK)
	_poly(
		[
			Vector2(-65, 11),
			Vector2(-55, 0),
			Vector2(46, -1),
			Vector2(61, 8),
			Vector2(65, 28),
			Vector2(54, 38),
			Vector2(-54, 38),
			Vector2(-65, 28)
		],
		BRASS
	)
	_poly([Vector2(-55, 0), Vector2(46, -1), Vector2(61, 8), Vector2(-61, 10)], Color("94805b"))
	_poly(
		[Vector2(-63, 13), Vector2(-37, 11), Vector2(-37, 35), Vector2(-54, 36), Vector2(-63, 27)],
		Color("655139")
	)
	_poly(
		[Vector2(33, 10), Vector2(60, 9), Vector2(64, 27), Vector2(53, 36), Vector2(33, 35)],
		Color("514533")
	)
	_poly([Vector2(-34, 12), Vector2(31, 11), Vector2(31, 34), Vector2(-34, 34)], Color("494232"))
	_line(Vector2(-59, 10), Vector2(59, 9), Color("b09a6b"), 1)
	_line(Vector2(-54, 37), Vector2(52, 37), Color("302e25"), 3)
	_line(Vector2(-52, 34), Vector2(51, 34), Color("8b7852"), 1)
	# Native-sized source plate fragments, without the old bright central crest.
	var body: Transform2D = pose.body_transform
	var impact := body.affine_inverse() * _armour_point
	var vibration: Vector2 = pose.armour_vibration
	var left_jolt := vibration if impact.x < 0 else Vector2.ZERO
	var right_jolt := vibration if impact.x >= 0 else Vector2.ZERO
	draw_texture_rect_region(
		MACHINE,
		Rect2(Vector2(-53, 10) + left_jolt, Vector2(11, 24)),
		Rect2(42, 70, 11, 24),
		Color(0.79, 0.77, 0.69)
	)
	draw_texture_rect_region(
		MACHINE,
		Rect2(Vector2(39, 10) + right_jolt, Vector2(11, 24)),
		Rect2(77, 70, 11, 24),
		Color(0.73, 0.74, 0.68)
	)
	for x: int in [-28, -15, -2, 11, 24]:
		draw_rect(Rect2(x, 17, 7, 9), Color("272b25"))
		_line(Vector2(x, 17), Vector2(x + 7, 17), Color("8d7852"), 1)
		if int(pose.phase) >= 2:
			draw_rect(Rect2(x + 2, 23, 2, 2), Color(Color("bc8a45"), float(pose.warm_light)))
	for at: Vector2 in [
		Vector2(-57, 13),
		Vector2(55, 12),
		Vector2(-32, 14),
		Vector2(30, 13),
		Vector2(-32, 31),
		Vector2(30, 31)
	]:
		_bolt(at, 2)
	for at: Vector2 in [Vector2(-60, 12), Vector2(-57, 14), Vector2(-53, 12), Vector2(47, 34)]:
		draw_rect(Rect2(at, Vector2(3, 2)), MOSS)
	_draw_gear(Vector2(-15, 39), 7, float(pose.gear_angle), Color("6b614b"))
	_draw_gear(Vector2(5, 40), 5, -float(pose.gear_angle) * 1.4, Color("82704c"))


func _draw_launcher(pose: Dictionary) -> void:
	# Main bell stays in its cage; only this independent cradle carries ammunition.
	_bolt(Vector2.ZERO, 6)
	_poly([Vector2(-5, -5), Vector2(22, -8), Vector2(29, -1), Vector2(24, 6), Vector2(-5, 6)], INK)
	_poly(
		[Vector2(0, -4), Vector2(21, -5), Vector2(24, 0), Vector2(21, 3), Vector2(0, 3)],
		Color("675741")
	)
	_line(Vector2(3, -4), Vector2(20, -5), EDGE, 1)
	_line(Vector2(22, -8), Vector2(25, 7), Color("a38a59"), 3)
	_line(Vector2(26, -7), Vector2(29, 6), Color("3c352b"), 3)
	if pose.mode in [&"lob_aim", &"lob_lock", &"lob_warning"]:
		draw_texture_rect_region(
			BELL, Rect2(9, -19, 12, 18), Rect2(0, 12, 28, 32), Color(1.1, 1.0, 0.85)
		)


func _draw_wheel(at: Transform2D, right: bool) -> void:
	draw_set_transform_matrix(at)
	_disk(Vector2.ZERO, 21, Color("242622"), 24)
	_disk(Vector2.ZERO, 18.5, Color("413d31"), 24)
	# Circular UVs exclude old cage/body pixels around the source wheel silhouette.
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var source := Vector2(105, 91) if right else Vector2(22, 91)
	for i: int in 32:
		var axis := Vector2.from_angle(float(i) * TAU / 32.0)
		vertices.append(axis * 19.5)
		uvs.append((source + axis * 21.0) / MACHINE.get_size())
	draw_polygon(vertices, PackedColorArray([Color(0.77, 0.75, 0.69)]), uvs, MACHINE)
	for i: int in 10:
		var axis := Vector2.from_angle(float(i) * TAU / 10.0)
		_line(axis * 19, axis * 21, Color("4d4b3d"), 2)
	_disk(Vector2.ZERO, 5, INK, 12)
	_disk(Vector2(-1, -1), 3, Color("8c7850"), 10)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_main_bell(pose: Dictionary) -> void:
	var cold := smoothstep(0.5, 0.98, float(pose.death_progress))
	var flash := float(pose.bell_flash)
	var copper := Color("be8744").lerp(Color("67523a"), cold).lerp(Color("ffe3a0"), flash)
	var lit := Color("ebba69").lerp(Color("8a7250"), cold).lerp(Color("fff1bd"), flash)
	# Authored in the same30x36 rectangle as the weak shape, clear lip and clapper.
	_poly(
		[
			Vector2(-8, -18),
			Vector2(7, -18),
			Vector2(10, -13),
			Vector2(11, 7),
			Vector2(15, 13),
			Vector2(14, 17),
			Vector2(-14, 17),
			Vector2(-15, 13),
			Vector2(-11, 7),
			Vector2(-10, -13)
		],
		INK
	)
	_poly(
		[
			Vector2(-7, -16),
			Vector2(6, -16),
			Vector2(8, -12),
			Vector2(9, 7),
			Vector2(13, 12),
			Vector2(12, 14),
			Vector2(-12, 14),
			Vector2(-13, 12),
			Vector2(-9, 7),
			Vector2(-8, -12)
		],
		copper
	)
	_poly(
		[Vector2(-6, -14), Vector2(-1, -16), Vector2(-2, 6), Vector2(-8, 10), Vector2(-7, -10)], lit
	)
	_poly(
		[Vector2(5, -13), Vector2(7, -10), Vector2(8, 7), Vector2(11, 10), Vector2(5, 8)],
		Color("80522b").lerp(Color("4a3c2e"), cold)
	)
	draw_texture_rect_region(
		BELL,
		Rect2(-13, -17, 26, 32),
		Rect2(1, 13, 26, 32),
		Color(1.7, 1.5, 1.12, 0.48 * (1 - cold * 0.4))
	)
	_line(Vector2(-11, 10), Vector2(11, 10), lit, 1)
	_poly([Vector2(-12, 14), Vector2(12, 14), Vector2(9, 17), Vector2(-9, 17)], Color("3b2c1e"))
	_line(Vector2(-11, 13), Vector2(11, 13), lit, 2)
	var clapper := Vector2(0, 10) + Vector2(0, 6).rotated(float(pose.clapper_angle))
	_line(Vector2(0, 8), clapper, Color("d7a85e").lerp(Color("6f5b3d"), cold), 2)
	_disk(clapper, 2.5, Color("e9b96b").lerp(Color("77603f"), cold), 8)
	if float(pose.death_progress) > 0.04:
		_line(Vector2(3, -13), Vector2(0, -6), INK, 1)
		_line(Vector2(0, -6), Vector2(4, 0), INK, 1)
		_line(Vector2(4, 0), Vector2(1, 7), INK, 1)


func _draw_wake(pose: Dictionary) -> void:
	if float(pose.speed) < 50 or pose.mode == &"dead":
		return
	var travel := float(pose.travel)
	var direction := float(pose.direction)
	for i: int in 4:
		var progress := fposmod(absf(travel) / 25.0 + float(i) * 0.25, 1.0)
		var at := Vector2(-direction * (49 + progress * 24), 63 - sin(progress * PI) * 4)
		draw_rect(Rect2(at.floor(), Vector2(2, 1)), Color(MOSS, 0.65 * (1 - progress)))


func _draw_impacts(pose: Dictionary) -> void:
	if pose.mode == &"dead":
		return
	var armour_age := float(pose.armour_hit_age)
	if armour_age >= 0 and armour_age < 0.18:
		var t := armour_age / 0.18
		for i: int in 4:
			var axis := Vector2.from_angle(-2.6 + float(i) * 0.7)
			var at := _armour_point + axis * (3 + t * 15) + Vector2(0, t * t * 12)
			draw_rect(Rect2(at.floor(), Vector2(2, 1)), Color(Color("d6af68"), 1 - t))
	var bell_age := float(pose.bell_hit_age)
	if bell_age >= 0 and bell_age < 0.22:
		var t := bell_age / 0.22
		var bell: Transform2D = pose.bell_transform
		for i: int in 3:
			var axis := Vector2.from_angle(-2.7 + float(i) * 1.1)
			draw_rect(
				Rect2(
					(bell.origin + axis * (16 + t * 12) + Vector2(0, t * t * 16)).floor(),
					Vector2(1, 2)
				),
				Color(Color("d8b471"), 1 - t)
			)


func _draw_loose_parts(pose: Dictionary) -> void:
	var death := float(pose.death_progress)
	if death < 0.38:
		return
	var drop := smoothstep(0.38, 0.82, death)
	var face := float(pose.direction)
	# Bounded cosmetic fall: no bodies/colliders or lingering particle nodes.
	for i: int in 3:
		var start := Vector2((-30 + i * 23) * face, -22 - i * 18)
		var end := Vector2((-68 + i * 53) * face, 61 - i % 2 * 3)
		var at := start.lerp(end, drop) + Vector2(0, -sin(drop * PI) * (9 + i * 3))
		draw_set_transform(at, float(i) * 0.7 + drop * (i + 1) * 1.4)
		if i == 1:
			_draw_gear(Vector2.ZERO, 6, 0, Color("6b5c42"))
		else:
			_poly([Vector2(-5, -2), Vector2(4, -3), Vector2(5, 2), Vector2(-4, 3)], Color("66553c"))
			_line(Vector2(-4, -2), Vector2(3, -2), Color("97805a"), 1)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_gear(at: Vector2, radius: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 32:
		points.append(
			(
				at
				+ (
					Vector2.from_angle(angle + float(i) * TAU / 32.0)
					* (radius if i % 4 in [1, 2] else radius - 2)
				)
			)
		)
	draw_colored_polygon(points, INK)
	_disk(at, radius - 2, color, 16)
	_disk(at, 2, INK, 8)
	for i: int in 3:
		var axis := Vector2.from_angle(angle + float(i) * TAU / 3.0)
		_line(at + axis * 2, at + axis * (radius - 3), Color("312d24"), 1)


func _bolt(at: Vector2, radius: float) -> void:
	_disk(at, radius, INK, 8)
	_disk(at + Vector2(-0.5, -0.5), maxf(1, radius - 1), Color("9a845a"), 8)


func _disk(at: Vector2, radius: float, color: Color, count: int) -> void:
	var points := PackedVector2Array()
	for i: int in count:
		points.append(at + Vector2.from_angle(float(i) * TAU / float(count)) * radius)
	draw_colored_polygon(points, color)


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, false)


func _armour_impact(point: Vector2) -> void:
	if is_instance_valid(encounter.motor):
		_armour_point = encounter.motor.to_local(point)


func _exit_tree() -> void:
	motion.dispose(encounter)
	if is_instance_valid(encounter) and encounter.armour_hit.is_connected(_armour_impact):
		encounter.armour_hit.disconnect(_armour_impact)
