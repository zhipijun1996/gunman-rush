@static_unload
class_name PixelVfx
extends RefCounted
## Shared read-only pixels. No nodes, clocks, callbacks, physics or random streams.
## Sprite shapes are authored offline with the pinned pixelfx tooling.
const CLIPS := {
	&"focus-gather": preload("res://assets/vfx/gunman-focus-gather/gunman-focus-gather.tres"),
	&"focus-restore": preload("res://assets/vfx/gunman-focus-restore/gunman-focus-restore.tres"),
	&"boss-land": preload("res://assets/vfx/gunman-boss-land/gunman-boss-land.tres"),
	&"chest-rays": preload("res://assets/vfx/gunman-chest-rays/gunman-chest-rays.tres"),
	&"loot-spill": preload("res://assets/vfx/gunman-loot-spill/gunman-loot-spill.tres"),
	&"coin-turn": preload("res://assets/vfx/gunman-coin-turn/gunman-coin-turn.tres"),
	&"muzzle": preload("res://assets/vfx/gunman-muzzle/gunman-muzzle.tres"),
	&"impact": preload("res://assets/vfx/gunman-impact/gunman-impact.tres"),
	&"dust": preload("res://assets/vfx/gunman-dust/gunman-dust.tres"),
	&"recoil": preload("res://assets/vfx/gunman-recoil/gunman-recoil.tres"),
	&"ice": preload("res://assets/vfx/gunman-ice/gunman-ice.tres"),
	&"cold": preload("res://assets/vfx/gunman-cold/gunman-cold.tres"),
	&"collect": preload("res://assets/vfx/gunman-collect/gunman-collect.tres"),
	&"heal": preload("res://assets/vfx/gunman-heal/gunman-heal.tres"),
	&"charge": preload("res://assets/vfx/gunman-charge/gunman-charge.tres"),
	&"ember": preload("res://assets/vfx/gunman-ember/gunman-ember.tres"),
	&"dissolve": preload("res://assets/vfx/gunman-dissolve/gunman-dissolve.tres"),
	&"spark": preload("res://assets/vfx/gunman-spark/gunman-spark.tres")
}
const INK := Color("172923")
const CREAM := Color("fff1c4")

static func reduced(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		if cursor.has_meta(&"reduced_vfx"): return bool(cursor.get_meta(&"reduced_vfx"))
		cursor = cursor.get_parent()
	return false

static func clip(canvas: CanvasItem, key: StringName, at: Vector2, progress: float, angle := 0.0, tint := Color.WHITE, size := Vector2.ONE) -> void:
	if not is_finite(progress) or progress < 0.0 or progress >= 1.0 or tint.a <= 0.0: return
	if reduced(canvas):
		if key in [&"dust",&"recoil",&"ember"]: return
		tint.a *= .6
	var frames: SpriteFrames = CLIPS.get(key)
	if frames == null: return
	var count := frames.get_frame_count(&"default")
	var index := mini(count-1, floori(progress*count))
	var texture := frames.get_frame_texture(&"default",index)
	var pivot: Vector2 = frames.get_meta(&"pivot")
	if canvas.texture_filter!=CanvasItem.TEXTURE_FILTER_NEAREST:
		canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_set_transform(at.round(),angle,size)
	canvas.draw_texture_rect(texture,Rect2(-pivot,texture.get_size()),false,tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func glint(canvas: CanvasItem, at: Vector2, radius: float, color: Color, strength := 1.0) -> void:
	var r := floorf(radius)
	if r < 1.0 or strength <= 0.0: return
	var center := at.round()
	if reduced(canvas): strength *= .55
	var shade := Color(INK,color.a*strength*.5)
	var light := Color(color,color.a*strength)
	canvas.draw_line(center-Vector2(r,0),center+Vector2(r,0),shade,3,false)
	canvas.draw_line(center-Vector2(0,r),center+Vector2(0,r),shade,3,false)
	canvas.draw_line(center-Vector2(r,0),center+Vector2(r,0),light,1,false)
	canvas.draw_line(center-Vector2(0,r),center+Vector2(0,r),light,1,false)
	canvas.draw_rect(Rect2(center,Vector2.ONE),Color(CREAM,light.a))

static func streak(canvas: CanvasItem, at: Vector2, axis: Vector2, length: float, width: float, color: Color, strength := 1.0) -> void:
	if length < 1.0 or width <= 0.0 or strength <= 0.0: return
	if reduced(canvas): strength *= .65
	var unit := axis.normalized()
	var side := unit.orthogonal()*width
	var root := at.round()
	var end := (at+unit*length).round()
	canvas.draw_colored_polygon(PackedVector2Array([(root-side).round(),end,(root+side).round()]),Color(color,color.a*strength))
	canvas.draw_line(root,end,Color(CREAM,color.a*strength*.7),1,false)

static func shard(canvas: CanvasItem, at: Vector2, axis: Vector2, length: float, width: float, color: Color, strength := 1.0) -> void:
	if length < 1.0 or width < .4 or strength <= 0.0: return
	if reduced(canvas): strength *= .65
	var tip := axis.normalized()*length*.5
	var side := axis.normalized().orthogonal()*width
	var center := at.round()
	canvas.draw_colored_polygon(PackedVector2Array([(center-tip).round(),(center-side).round(),(center+tip).round(),(center+side).round()]),Color(color.darkened(.35),color.a*strength))
	canvas.draw_colored_polygon(PackedVector2Array([(center-tip).round(),(center-side).round(),(center+tip).round()]),Color(color,color.a*strength))
	canvas.draw_line(center-tip*.6,center+tip*.6,Color(CREAM,color.a*strength*.8),1,false)

static func arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, end: float, color: Color, width := 1.0) -> void:
	# Sample on the actual world-pixel grid, rather than anti-aliased vector rings.
	if radius <= 0.0 or color.a <= 0.0 or end <= start: return
	var count := clampi(ceili((end-start)*radius*.5),3,64)
	var points := PackedVector2Array()
	for i: int in count+1:
		points.append((center+Vector2.from_angle(lerpf(start,end,float(i)/count))*radius).round())
	canvas.draw_polyline(points,color,width,false)

static func hazard_patch(canvas: CanvasItem, bounds: Rect2, phase: float) -> void:
	# Exact accepted damage envelope; sparse roots make the support and actor clear.
	canvas.draw_rect(bounds,Color(.64,.25,.30,.16))
	canvas.draw_rect(bounds,Color(.78,.43,.35,.65),false,1)
	var count := maxi(2,floori(bounds.size.x/12))
	for i: int in count:
		var x := lerpf(bounds.position.x+3,bounds.end.x-3,float(i)/maxi(1,count-1))
		var root := Vector2(x,bounds.end.y)
		var tip := Vector2(clampf(x+sin(i*2+phase*5)*3,bounds.position.x,bounds.end.x),bounds.position.y+1)
		canvas.draw_line(root,tip,Color("8a4e45"),3,false)
		canvas.draw_line(root-Vector2(1,0),tip,Color("df9f69"),1,false)
		canvas.draw_line(tip,tip+Vector2(0,minf(3,bounds.size.y*.2)),Color("ffe0a0"),1,false)
