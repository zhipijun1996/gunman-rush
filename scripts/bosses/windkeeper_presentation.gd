class_name WindkeeperPresentation
extends Node2D
@export var encounter: WindkeeperEncounter
const BODY := preload("res://assets/plains_v4/windkeeper/body_actions.png")
const PARTS := preload("res://assets/plains_v4/windkeeper/parts.png")
const BODY_REGIONS := [Rect2(8,45,482,463),Rect2(520,35,450,473),Rect2(985,105,543,403),Rect2(10,575,512,390),Rect2(515,550,490,420),Rect2(1010,590,515,378)]
const FOOT_ANCHORS := [Vector2(240,457),Vector2(230,467),Vector2(271,397),Vector2(256,382),Vector2(245,413),Vector2(258,368)]
var visual_clock := 0.0
var hurt_flash := 0.0
func _ready() -> void:
	if encounter != null: encounter.damageable.damaged.connect(func(_context: Dictionary) -> void: hurt_flash = .14)
func _process(delta: float) -> void:
	visual_clock += delta
	hurt_flash = maxf(0,hurt_flash-delta)
	queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var frame := 0
	if encounter.health.terminal: frame = 5
	elif encounter.mode == &"stomp_warning": frame = 1
	elif encounter.mode in [&"charge",&"charge_warning",&"chase"]: frame = 2
	elif encounter.core_open: frame = 3
	elif encounter.stage_phase == 2: frame = 4
	var facing := 1.0 if encounter.direction > 0 else -1.0
	var breathe := sin(visual_clock*2)*1.2 if frame == 0 else 0.0
	draw_set_transform(Vector2(0,65+breathe),0,Vector2(facing,1)*.35)
	draw_texture_rect_region(BODY,Rect2(-FOOT_ANCHORS[frame],BODY_REGIONS[frame].size),BODY_REGIONS[frame],Color(1.3,1.15,.8) if hurt_flash > 0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if not encounter.health.terminal:
		# Independent genuine painted rotor rotates around measured hub.
		var angle := encounter.blade_angle if encounter.stage_phase == 2 else visual_clock*.4
		draw_set_transform(Vector2(0,-75),angle,Vector2.ONE*.34)
		draw_texture_rect_region(PARTS,Rect2(-Vector2(323,286),Vector2(640,605)),Rect2(5,5,640,605))
		draw_set_transform(Vector2.ZERO)
	if encounter.mode in [&"charge_warning",&"stomp_warning",&"blade_warning"]:
		draw_arc(Vector2(0,65),88,PI,TAU,24,Color(1,.65,.23,.7),4)
	if encounter.core_open:
		var core := encounter.core_offset()
		draw_circle(core,25+sin(visual_clock*9)*2,Color(1,.83,.33,.3))
		draw_texture_rect_region(PARTS,Rect2(core-Vector2(11,14),Vector2(22,29)),Rect2(735,20,435,575))
