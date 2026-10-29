class_name ThornForestPresentation
extends Node2D
@export var encounter: ThornForestEncounter
var age := 0.0
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
func _process(delta: float) -> void:
	age += delta
	motion.sample(encounter,delta)
	queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var alive := not encounter.health.terminal
	var size := encounter.definition.collision_size
	var bark := Color(.24,.3,.22) if alive else Color(.18,.2,.17)
	bark = hit_template.tint(bark)
	# The rooted foot and heart stay registered; the upper trunk bows between
	# its real attack states, with separate shoulder, elbow and twig chains.
	var shoulder_y := -size.y*.32+motion.death*size.y*.16
	var top := Vector2(motion.crown_angle()*size.y*.18,-size.y*.5+motion.death*size.y*.20)
	var trunk := PackedVector2Array([Vector2(-size.x*.5,size.y*.5),Vector2(-size.x*.5,shoulder_y),top+Vector2(-size.x*.42,0),top+Vector2(size.x*.42,0),Vector2(size.x*.5,shoulder_y),Vector2(size.x*.5,size.y*.5)])
	draw_colored_polygon(trunk,bark)
	var outline := PackedVector2Array(trunk)
	outline.append(trunk[0])
	draw_polyline(outline,bark.lightened(.2),3)
	for side: int in [-1,1]:
		var shoulder := Vector2(side*24,-8)
		var elbow := shoulder+Vector2(side*20,-20).rotated(motion.limb_angle(side))
		var tip := elbow+Vector2(side*16,-10).rotated(-motion.limb_angle(side)*.55)
		draw_line(shoulder,elbow,bark.lightened(.12),14)
		draw_line(elbow,tip,bark.lightened(.16),9)
		for n: int in 3:
			var p := shoulder.lerp(tip,float(n+1)/4.0)
			draw_line(p,p+Vector2(side*15,-7).rotated(motion.limb_angle(side)),Color(.5,.34,.36),4)
	var heart := Vector2(encounter.weak_side*18 if encounter.stage_phase > 1 else 0, -9)
	draw_circle(heart,18,Color(.16,.12,.17))
	draw_arc(heart,19,0,TAU,32,Color(1,.78,.34) if encounter.core_open else Color(.5,.4,.25),3)
	if encounter.core_open: draw_circle(heart,11+sin(age*5),Color(1,.82,.42))
	else:
		for side: int in [-1,1]: draw_line(heart+Vector2(side*14,-15),heart+Vector2(-side*14,15),Color(.4,.53,.26),6)
	if (encounter.definition as ThornForestDefinition).queen:
		for i: int in 5:
			var root := top+Vector2((i-2)*11,0)
			draw_line(root,root+Vector2((i-2)*6,-23-abs(i-2)*4).rotated(motion.crown_angle()),Color(.62,.35,.43),6)
	if encounter.has_ground_mark and encounter.mode in [&"branch_warning",&"seed_flight"]:
		var goal := to_local(encounter.attack_goal)
		var width := (encounter.definition as ThornForestDefinition).seed_zone_size.x
		draw_line(goal-Vector2(width*.5,1),goal+Vector2(width*.5,-1),Color(1,.65,.35),4)
		draw_arc(goal,width*.5,PI,TAU,24,Color(1,.65,.35,.8),2)
func _exit_tree() -> void:
	motion.dispose(encounter)
