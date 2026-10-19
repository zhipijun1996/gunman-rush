extends SceneTree
var checks:=0
var failures:=0
var state:=918374
var rows:Array=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("AUDIT FAIL ",message)
func rand_int(n:int)->int:
	state=(state*1664525+1013904223)&0xffffffff
	return state%n
func occupied(point:Vector2,rects:Array[Rect2])->bool:
	for rect:Rect2 in rects:
		if rect.has_point(point):return true
	return false
func examine(rects:Array[Rect2],label:String)->void:
	var plan:=PixelFormalTerrain.geometry_plan(rects)
	var pieces:Array[Rect2]=[];pieces.assign(plan.pieces)
	var xs:Array[float]=[];var ys:Array[float]=[]
	for r:Rect2 in rects:
		for x:float in [r.position.x,r.end.x]:
			if x not in xs:xs.append(x)
		for y:float in [r.position.y,r.end.y]:
			if y not in ys:ys.append(y)
	xs.sort();ys.sort()
	for i:int in xs.size()-1:
		for j:int in ys.size()-1:
			var p:=Vector2((xs[i]+xs[i+1])/2,(ys[j]+ys[j+1])/2)
			check(occupied(p,rects)==occupied(p,pieces),label+" critical cell occupancy "+str(p))
	var split:Array[Rect2]=[]
	for r:Rect2 in rects:
		split.append(Rect2(r.position,Vector2(r.size.x*.5,r.size.y)))
		split.append(Rect2(r.position+Vector2(r.size.x*.5,0),Vector2(r.size.x*.5,r.size.y)))
	check(plan==PixelFormalTerrain.geometry_plan(split),label+" same union halved authoring")
	var reverse:=rects.duplicate();reverse.reverse()
	check(plan==PixelFormalTerrain.geometry_plan(reverse),label+" reverse order")
	var art:=PixelFormalTerrain.build(rects)
	check(art!=null,label+" actual builder accepts")
	if art!=null:
		for child:Node in art.get_children():check(not child is CollisionObject2D,label+" collisionless art")
		art.free()
	rows.append({"label":label,"input_rectangles":rects.size(),"pieces":pieces.size(),"faces":plan.edges.size()})
func _initialize()->void:run.call_deferred()
func run()->void:
	for c:int in 60:
		var rects:Array[Rect2]=[]
		for n:int in 2+rand_int(14):rects.append(Rect2((rand_int(160)-80)*.125,(rand_int(160)-80)*.125,(1+rand_int(100))*.125,(1+rand_int(100))*.125))
		examine(rects,"random/%s"%c)
	examine([Rect2(-4,-4,4,4),Rect2(0,0,4,4)],"diagonal contact")
	examine([Rect2(0,0,24,18),Rect2(24.125,0,24,18)],"thin positive gap")
	var tuning:=PlayerTuning.load_default()
	for difficulty:String in ["intro","advanced"]:
		for suffix:String in ["","/08"]:
			var generator:=PlainsRegionGenerator.new();generator.root_bell_mode="v3"
			var result:=generator.generate("level-design-v2-baseline"+suffix,tuning,false,"",difficulty)
			check(result.ok,"formal generator")
			if not result.ok:continue
			var solids:Array[Rect2]=[]
			for n:Dictionary in result.manifest.nodes:
				var d:=PlainsRegionGenerator.definition(n)
				for i:int in d.platforms.size():
					if i not in d.one_way_platform_indices:solids.append(Rect2(Vector2(n.offset[0],n.offset[1])+d.platforms[i].position,d.platforms[i].size))
			for a:Array in result.manifest.ground_supports:solids.append(Rect2(a[0],a[1],a[2],a[3]))
			examine(solids,"formal/"+difficulty+suffix)
	var report:Dictionary={"checks":checks,"failures":failures,"scope":"independent critical-coordinate occupancy oracle, partition/order invariance and actual builder; no GPU/route claim","rows":rows}
	var f:=FileAccess.open("res://build/pixel-formal-audit/adversarial_union.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ")+"\n");f.close()
	print("ADVERSARIAL_UNION checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
