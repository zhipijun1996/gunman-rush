class_name ControlGuideDiagram
extends Control
## Native UI illustration, never an input surface or a gameplay simulation.
var device: StringName = &"keyboard_mouse"
var profile: Dictionary
var style := "generic"
var reduced := false
var age := 0.0
const COURIER := preload("res://assets/player_presentation_01/motion_v1/motion_source.png")
const CLIP := preload("res://game/player/presentation/resources/motion_clip_data.gd")
func _ready() -> void:
	custom_minimum_size = Vector2(0,140)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:custom_minimum_size.y=140 if size.x>=570 else 280)
func _process(delta: float) -> void:
	if reduced: return
	age += delta
	queue_redraw()
func caption(at: Vector2, value: String, tint: Color = UnderworldUI.TEXT) -> void:
	draw_string(UnderworldUI.FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,16,tint)
func _draw() -> void:
	if profile.is_empty(): return
	var wide:=size.x>=570
	var origin := Vector2(size.x*.5-(270 if wide else 130),14)
	var phase := fmod(age,2.4)/2.4
	var holding := phase<.7
	var pulse := .6 if reduced else .35+.3*sin(age*3)*sin(age*3)
	draw_style_box(UnderworldUI.box(UnderworldUI.INK,UnderworldUI.BORDER,8),Rect2(origin-Vector2(12,8),Vector2(284,125)))
	if device==&"gamepad":
		draw_style_box(UnderworldUI.box(UnderworldUI.RAISED,UnderworldUI.BRASS,4),Rect2(origin+Vector2(25,30),Vector2(210,65)))
		for x: float in [78,154]:
			draw_circle(origin+Vector2(x,78),15,UnderworldUI.INK)
			draw_circle(origin+Vector2(x,78)+(Vector2(8,-6) if x>100 and holding else Vector2.ZERO),5,UnderworldUI.BRASS)
		var labels := [PlayerControlGuide.pad_face(JOY_BUTTON_A,style),PlayerControlGuide.pad_face(JOY_BUTTON_B,style),PlayerControlGuide.pad_face(JOY_BUTTON_X,style),PlayerControlGuide.pad_face(JOY_BUTTON_Y,style)]
		for i: int in 4:
			var at: Vector2 = origin+Vector2(207,67)+[Vector2(0,18),Vector2(18,0),Vector2(-18,0),Vector2(0,-18)][i]
			draw_circle(at,8,UnderworldUI.BORDER)
			caption(at+Vector2(-5,5),labels[i] if style!="generic" else ["↓","→","←","↑"][i])
		caption(origin+Vector2(22,16),"L1 / LB")
		caption(origin+Vector2(182,16),"R1 / RB",UnderworldUI.TEXT if holding else UnderworldUI.BRASS)
	else:
		var left := origin+Vector2(58,59)
		var right := origin+Vector2(202,59)
		if device==&"touch":
			for at: Vector2 in [left,right]:
				draw_circle(at,31,UnderworldUI.RAISED)
				draw_arc(at,31,0,TAU,40,UnderworldUI.BORDER,1)
			var offset := Vector2(20,-13)*smoothstep(0,.4,minf(phase,.4)) if holding else Vector2.ZERO
			draw_circle(right+offset,9,Color(UnderworldUI.BRASS,pulse))
			caption(left+Vector2(-17,51),PlayerControlGuide.text("diagram.move"))
		else:
			for i: int in 3:
				var rect := Rect2(left+Vector2(-48+i*32,0),Vector2(28,28))
				draw_style_box(UnderworldUI.box(UnderworldUI.RAISED,UnderworldUI.BORDER,3),rect)
				caption(rect.position+Vector2(4,21),[PlayerControlGuide.key(profile,"left").split(" / ")[0],"↓",PlayerControlGuide.key(profile,"right").split(" / ")[0]][i])
			draw_style_box(UnderworldUI.box(UnderworldUI.RAISED,UnderworldUI.BRASS,3),Rect2(right-Vector2(23,30),Vector2(46,66)))
			var button := int(profile.mouse_shoot_button)
			var button_rect := Rect2(right+Vector2(2,-26),Vector2(17,23)) if button==MOUSE_BUTTON_RIGHT else Rect2(right-Vector2(3,26),Vector2(6,23)) if button==MOUSE_BUTTON_MIDDLE else Rect2(right-Vector2(19,26),Vector2(17,23))
			draw_rect(button_rect,Color(UnderworldUI.BRASS,pulse if holding else .15))
		if not holding:
			var radius := 6+(phase-.7)*60
			draw_arc(right,radius,0,TAU,32,Color(UnderworldUI.BRASS,clampf((1-phase)*2,0,1)),1.5)
		caption(right+Vector2(-17,51),PlayerControlGuide.text("diagram.hold" if holding else "diagram.release"),UnderworldUI.BRASS)
	_draw_recoil(origin+Vector2(300 if wide else 0,0 if wide else 140),phase)

func _draw_recoil(base: Vector2, phase: float) -> void:
	draw_style_box(UnderworldUI.box(UnderworldUI.INK,UnderworldUI.BORDER,8),Rect2(base-Vector2(8,8),Vector2(248,125)))
	caption(base+Vector2(0,13),PlayerControlGuide.text("diagram.recoil"))
	var progress:=clampf((phase-.25)/.45,0,1)
	var foot:=base+Vector2(45+progress*130,94-sin(clampf(phase/.8,0,1)*PI)*28)
	var entry:Dictionary=CLIP.DATA.frames.idle[0]
	var r:Array=entry.rect
	var pivot:Array=entry.pivot
	var factor:=32.0/float(CLIP.DATA.reference_body_height)
	var tint:=Color(1,1,1,1.0 if phase<.85 else 1-(phase-.85)/.15)
	draw_texture_rect_region(COURIER,Rect2(foot-Vector2(pivot[0],pivot[1])*factor,Vector2(r[2],r[3])*factor),Rect2(r[0],r[1],r[2],r[3]),tint)
	draw_line(base+Vector2(15,96),base+Vector2(218,96),UnderworldUI.BORDER,1)
	if phase>.25 and phase<.65:
		var shot:=foot+Vector2(-15,-17)
		draw_line(shot,shot-Vector2(24,0),UnderworldUI.BRASS,2)
		draw_line(foot+Vector2(16,-15),foot+Vector2(40,-15),UnderworldUI.COOL,2)
		draw_line(foot+Vector2(40,-15),foot+Vector2(34,-20),UnderworldUI.COOL,2)
		draw_line(foot+Vector2(40,-15),foot+Vector2(34,-10),UnderworldUI.COOL,2)
