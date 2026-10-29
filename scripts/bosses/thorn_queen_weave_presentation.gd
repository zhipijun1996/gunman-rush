extends Node2D
@export var encounter: ThornQueenV2
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
func _process(delta: float) -> void:
	motion.sample(encounter,delta)
	queue_redraw()
func _draw() -> void:
	if encounter==null: return
	var size := encounter.definition.collision_size
	var crown := Vector2(motion.crown_angle()*18,-size.y*.5-18+motion.death*20)
	var shoulders := [Vector2(-16,-size.y*.5),Vector2(16,-size.y*.5)]
	var edges: Array[Vector2] = []
	for side: int in [-1,1]:
		var shoulder: Vector2 = shoulders[0 if side < 0 else 1]
		edges.append(shoulder+Vector2(side*(size.x*.5-16),size.y*.5).rotated(motion.limb_angle(side)*.6))
	draw_colored_polygon(PackedVector2Array([edges[0],shoulders[0],crown,shoulders[1],edges[1],Vector2(0,size.y*.5)]),hit_template.tint(Color("9c677e").lightened(float(motion.phase-1)*.05) if not encounter.health.terminal else Color("635866")))
	draw_circle(Vector2.ZERO,10,Color("efc591") if not encounter.health.terminal else Color("8d7b6d"))
	draw_arc(Vector2.ZERO,15,0,TAU,24,Color("fae4b4"),2)
	for side: int in [-1,1]:
		var shoulder := Vector2(side*18,-3)
		var elbow := shoulder+Vector2(side*12,10).rotated(motion.limb_angle(side))
		var tip := elbow+Vector2(side*8,11).rotated(-motion.limb_angle(side)*.5)
		draw_line(shoulder,elbow,Color("b68ca3"),5)
		draw_line(elbow,tip,Color("b68ca3"),3)

	if encounter._weave_bound and encounter.motion_mode in ["migration_preview","phase_preview"]:
		var path := encounter.motion_path()
		for index: int in path.size()-1:
			draw_dashed_line(to_local(path[index]),to_local(path[index+1]),Color("dfb684"),2,10,true,true)
			draw_circle(to_local(path[index+1]),7,Color("efc591"))

func _exit_tree() -> void:
	motion.dispose(encounter)
