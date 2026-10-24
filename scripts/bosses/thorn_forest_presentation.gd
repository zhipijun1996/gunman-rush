class_name ThornForestPresentation
extends Node2D
@export var encounter: ThornForestEncounter
var age := 0.0
var hit_template: EnemyHitTemplate
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var alive := not encounter.health.terminal
	var size := encounter.definition.collision_size
	var bark := Color(.24,.3,.22) if alive else Color(.18,.2,.17)
	bark = hit_template.tint(bark)
	draw_style_box(_bark_style(bark),Rect2(-size*.5,size))
	for side: int in [-1,1]:
		var branch := PackedVector2Array([Vector2(side*24,20),Vector2(side*60,-28),Vector2(side*48,-38),Vector2(side*18,-8)])
		draw_colored_polygon(branch, bark.lightened(.12))
		for n: int in 3:
			var p := Vector2(side*(30+n*8),-4-n*10)
			draw_line(p,p+Vector2(side*15,-7),Color(.5,.34,.36),4)
	var heart := Vector2(encounter.weak_side*18 if encounter.stage_phase > 1 else 0, -9)
	draw_circle(heart,18,Color(.16,.12,.17))
	draw_arc(heart,19,0,TAU,32,Color(1,.78,.34) if encounter.core_open else Color(.5,.4,.25),3)
	if encounter.core_open: draw_circle(heart,11+sin(age*5),Color(1,.82,.42))
	else:
		for side: int in [-1,1]: draw_line(heart+Vector2(side*14,-15),heart+Vector2(-side*14,15),Color(.4,.53,.26),6)
	if (encounter.definition as ThornForestDefinition).queen:
		for i: int in 5:
			draw_line(Vector2((i-2)*11,-size.y*.5),Vector2((i-2)*17,-size.y*.5-23-abs(i-2)*4),Color(.62,.35,.43),6)
	if encounter.has_ground_mark and encounter.mode in [&"branch_warning",&"seed_flight"]:
		var goal := to_local(encounter.attack_goal)
		var width := (encounter.definition as ThornForestDefinition).seed_zone_size.x
		draw_line(goal-Vector2(width*.5,1),goal+Vector2(width*.5,-1),Color(1,.65,.35),4)
		draw_arc(goal,width*.5,PI,TAU,24,Color(1,.65,.35,.8),2)
func _bark_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	return style
