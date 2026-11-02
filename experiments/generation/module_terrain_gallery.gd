class_name ModuleTerrainGallery
extends CanvasLayer
## Golden-sample candidate gallery. Not a gameplay acceptance or formal map.
signal region_requested
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
	label_at("TERRAIN MATERIAL STUDY / approved palette / geometry studies",Vector2(28,135),23)
	label_at("Same boundary + same material coordinates. 32px cell. Collision and map generation unchanged.",Vector2(28,170))
	var next:=Button.new();next.text="NEXT SAMPLE";next.position=Vector2(1010,137);next.pressed.connect(func()->void:page=(page+1)%4;refresh.call_deferred());body.add_child(next)
	var packing:=Button.new();packing.text="MACROS" if use_macros else "1x1 ONLY";packing.position=Vector2(880,137);packing.pressed.connect(func()->void:use_macros=not use_macros;refresh.call_deferred());body.add_child(packing)
	var region:=Button.new();region.text="PLAYABLE REGION STUDY";region.position=Vector2(985,655);region.pressed.connect(func()->void:region_requested.emit());body.add_child(region)
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
	elif page==1:
		var tiles:=PlainsTileComposer.catalog();var masks:Array=tiles.keys();masks.sort()
		for index:int in masks.size():
			var mask:int=masks[index];var cells:Dictionary={Vector2i(1,1):true}
			for i:int in 8:
				if mask&(1<<i):cells[Vector2i(1,1)+PlainsTileComposer.OFFSETS[i]]=true
			var painted:=PlainsTileComposer.build(cells);painted.scale=Vector2.ONE*.68;painted.position=Vector2(30+(index%12)*103,226+(index/12)*115);body.add_child(painted)
			label_at("%03d"%mask,painted.position-Vector2(0,22),13)

	elif page==2:
		var tests:Array[Dictionary]=[
			{"name":"EXACT / fractional thin row","at":Vector2(35,245),"solids":[Rect2(0,0,383.5,8.5)]},
			{"name":"EXACT / 24 high + 57 high","at":Vector2(455,245),"solids":[Rect2(0,0,190.25,24),Rect2(190.25,0,193.25,57.25)]},
			{"name":"EXACT / overlapping L","at":Vector2(880,245),"solids":[Rect2(0,0,51.5,119.5),Rect2(0,87.25,193.5,32.25)]},
			{"name":"EXACT / steps","at":Vector2(35,447),"solids":[Rect2(0,0,51.25,128),Rect2(51.25,29.75,66.5,98.25),Rect2(117.75,60.5,140.75,67.5)]},
			{"name":"EXACT / fractional hole","at":Vector2(340,447),"solids":[Rect2(0,0,257.5,23.5),Rect2(0,23.5,41.25,100),Rect2(219.25,23.5,38.25,100),Rect2(0,99.5,257.5,24)]},
			{"name":"EXACT / T","at":Vector2(650,447),"solids":[Rect2(0,0,290.5,23.5),Rect2(129.25,23.5,27.5,104.5)]}]
		for entry:Dictionary in tests:
			label_at(entry.name,entry.at-Vector2(0,30))
			var solids:Array[Rect2]=[]
			for rect:Rect2 in entry.solids:
				if use_macros:solids.append(rect)
				else:
					var left:=Rect2(rect.position,Vector2(rect.size.x*.37,rect.size.y))
					solids.append(left)
					solids.append(Rect2(Vector2(left.end.x,rect.position.y),Vector2(rect.end.x-left.end.x,rect.size.y)))
			var painted:=PlainsTileComposer.build_rectangles(solids);painted.position=entry.at;body.add_child(painted)
	else:
		label_at("SUSPENDED SOLIDS / one row, variable length, exact physical thickness",Vector2(35,215),19)
		for row:int in 3:
			var height:float=[8.5,24.0,32.0][row]
			var x:=35.0
			for width:float in [8,32,64,96,192,384]:
				var solids:Array[Rect2]=[Rect2(0,0,width,height)]
				if not use_macros:solids=[Rect2(0,0,width*.375,height),Rect2(width*.375,0,width*.625,height)]
				var painted:=PlainsTileComposer.build_rectangles(solids)
				painted.position=Vector2(x,300+row*115);body.add_child(painted)
				label_at("%s x %s"%[width,height],painted.position-Vector2(0,30),13)
				x+=width+75
	label_at("Local topology coverage is testable. Beauty, readable edges and repetition require visual review.",Vector2(28,655))
