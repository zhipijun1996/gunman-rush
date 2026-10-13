class_name ModuleTerrainGallery
extends CanvasLayer
## Golden-sample candidate gallery. Not a gameplay acceptance or formal map.
var page:=0
var use_macros:=true
var body:Control
func _ready()->void:
	layer=8
	body=Control.new();add_child(body);refresh()
func shape(rows:Array)->Dictionary:
	var cells:Dictionary={}
	for y:int in rows.size():
		for x:int in rows[y].length():
			if rows[y][x]=="#":cells[Vector2i(x,y)]=true
	return cells
func label_at(text:String,at:Vector2,size:int=15)->void:
	var label:=Label.new();label.text=text;label.position=at;label.add_theme_font_size_override("font_size",size);body.add_child(label)
func refresh()->void:
	for child:Node in body.get_children():child.free()
	var bg:=ColorRect.new();bg.position=Vector2(0,118);bg.size=Vector2(1280,602);bg.color=Color("283d3c");body.add_child(bg)
	label_at("TERRAIN MATERIAL STUDY / candidate — player art approval pending",Vector2(28,135),23)
	label_at("Same boundary + same material coordinates. 32px cell. Collision and map generation unchanged.",Vector2(28,170))
	var next:=Button.new();next.text="SHAPES / 47 MASKS";next.position=Vector2(1010,137);next.pressed.connect(func()->void:page=1-page;refresh.call_deferred());body.add_child(next)
	var packing:=Button.new();packing.text="MACROS" if use_macros else "1x1 ONLY";packing.position=Vector2(880,137);packing.pressed.connect(func()->void:use_macros=not use_macros;refresh.call_deferred());body.add_child(packing)
	if page==0:
		var cases:Array[Dictionary]=[
			{"name":"ONE ROW / 1x1 tiles","rows":["############"],"at":Vector2(35,245),"macro":Vector2i.ONE},
			{"name":"TWO ROWS / 2x1 tiles","rows":["############","############"],"at":Vector2(455,245),"macro":Vector2i(2,1)},
			{"name":"L / concave + convex","rows":["##....","##....","######","######"],"at":Vector2(880,245),"macro":Vector2i(2,2)},
			{"name":"STAIRS / 1x2 tiles","rows":["##......","####....","######..","########"],"at":Vector2(35,447),"macro":Vector2i(1,2)},
			{"name":"RING / hole stays empty","rows":["########","##....##","##....##","########"],"at":Vector2(340,447),"macro":Vector2i(2,2)},
			{"name":"T / one-cell walls","rows":["#########","....#....","....#....","....#...."],"at":Vector2(650,447),"macro":Vector2i.ONE},
			{"name":"ISOLATED / narrow","rows":["#.#","..#","..#","..#"],"at":Vector2(1010,447),"macro":Vector2i.ONE}]
		for entry:Dictionary in cases:
			label_at(entry.name,entry.at-Vector2(0,30))
			var painted:=PlainsTileComposer.build(shape(entry.rows),entry.macro if use_macros else Vector2i.ONE);painted.position=entry.at;body.add_child(painted)
	else:
		var tiles:=PlainsTileComposer.catalog();var masks:Array=tiles.keys();masks.sort()
		for index:int in masks.size():
			var mask:int=masks[index];var cells:Dictionary={Vector2i(1,1):true}
			for i:int in 8:
				if mask&(1<<i):cells[Vector2i(1,1)+PlainsTileComposer.OFFSETS[i]]=true
			var painted:=PlainsTileComposer.build(cells);painted.scale=Vector2.ONE*.68;painted.position=Vector2(30+(index%12)*103,226+(index/12)*115);body.add_child(painted)
			label_at("%03d"%mask,painted.position-Vector2(0,22),13)
	label_at("Local topology coverage is testable. Beauty, readable edges and repetition require visual review.",Vector2(28,655))
