extends SceneTree
var checks: int=0
var failures: Array[String]=[]
var output: String="/workspace/scratch/foreground-helper-independent/result.json"
var samples: Dictionary={}
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func need(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func exposed_pair(old: Node,new: Node,bounds: Rect2,size: Vector2,masks: Array,label: String) -> void:
	old.call("set_masks",masks);new.call("set_masks",masks)
	var a: Array=old.call("_exposed_regions",bounds,size)
	var b: Array=new.call("_exposed_regions",bounds,size)
	need(a==b,"exposed exact ordered rectangles "+label)
	if label=="fragmentation64":
		need(a.size()==55,"original64 fragment fallback exercised")
		samples["fragmentation_fallback_regions"]=a.size()
func run() -> void:
	root.size=Vector2i(1280,720)
	var old_script: Script=load("/workspace/scratch/foreground-helper-independent/old_helper.gd")
	var new_script: Script=load("/workspace/scratch/foreground-helper-independent/new_helper.gd")
	var old: Node=old_script.new();var fresh: Node=new_script.new()
	root.add_child(old);root.add_child(fresh)
	var size:=Vector2(200,200)
	exposed_pair(old,fresh,Rect2(250,250,20,20),size,[],"empty")
	exposed_pair(old,fresh,Rect2(0,0,200,200),size,[Rect2(203,0,5,200)],"touch strict edge")
	exposed_pair(old,fresh,Rect2(5,5,20,20),size,[Rect2(-10,-10,250,250)],"contained")
	exposed_pair(old,fresh,Rect2(0,0,200,200),size,[Rect2(-50,-50,10,10),Rect2(250,250,10,10)],"disjoint")
	var fragmented: Array[Rect2]=[]
	for i: int in 10:fragmented.append(Rect2(10+i*20,-3,2,206))
	for i: int in 10:fragmented.append(Rect2(-3,10+i*20,206,2))
	exposed_pair(old,fresh,Rect2(0,0,200,200),size,fragmented,"fragmentation64")
	var rng:=RandomNumberGenerator.new();rng.seed=20261023
	for index: int in 250:
		var masks: Array[Rect2]=[]
		for j: int in rng.randi_range(0,40):masks.append(Rect2(rng.randi_range(-100,300),rng.randi_range(-100,300),rng.randi_range(0,250),rng.randi_range(0,250)))
		var bounds:=Rect2(rng.randi_range(-100,250),rng.randi_range(-100,250),rng.randi_range(0,300),rng.randi_range(0,300))
		exposed_pair(old,fresh,bounds,size,masks,"seeded%d"%index)
	var transforms: Array[Transform2D]=[Transform2D.IDENTITY,Transform2D(Vector2(2,.25),Vector2(-.3,.75),Vector2(300,-120)),Transform2D(-.43,Vector2(.8,1.5),.1,Vector2(-700,250))]
	for transform: Transform2D in transforms:
		root.canvas_transform=transform
		old.call("begin_pass");fresh.call("begin_pass")
		need(fresh.get("_protection_canvas")==root.get_canvas_transform(),"snapshot current canvas")
		need(fresh.get("_protection_viewport")==root.get_visible_rect(),"snapshot current viewport")
		for i: int in 150:
			var rect:=Rect2(rng.randi_range(-1000,1800),rng.randi_range(-700,1200),rng.randi_range(0,400),rng.randi_range(0,400))
			var source: String=["player","actual_static_geometry_and_functions","actual_moving_platform_edge","actual_visible_ui"][i%4]
			old.call("_world_rect",rect,source);fresh.call("_world_rect",rect,source)
			need(old.call("state")==fresh.call("state"),"world projection/clipping/merge step%d"%i)
	# Explicit overflow/disjoint/edge-zero probes, preserving counts and classification.
	root.canvas_transform=Transform2D.IDENTITY
	old.call("begin_pass");fresh.call("begin_pass")
	for i: int in 70:
		var rect:=Rect2((i%20)*60+2,(i/20)*60+2,3,3)
		old.call("_add",rect,"actual_visible_ui");fresh.call("_add",rect,"actual_visible_ui")
	need(old.call("state")==fresh.call("state"),"overflow clipping equality")
	need(bool(fresh.get("_overflow")),"MAX_PROTECTION overflow exercised")
	for rect: Rect2 in [Rect2(1280,5,20,20),Rect2(-20,5,20,20),Rect2(0,0,0,5),Rect2(-20,-20,1400,800)]:
		old.call("_add",rect,"player");fresh.call("_add",rect,"player")
		need(old.call("state")==fresh.call("state"),"screen edge empty/containing equality")
	var report:={"scope":"Actual old/new extracted pure helpers only. No admission, rendered pixel, gameplay, performance or full FG suite acceptance.","checks":checks,"failures":failures,"samples":samples,"source_extraction":JSON.parse_string(FileAccess.get_file_as_string("/workspace/scratch/foreground-helper-independent/extraction.json"))}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	old.free();fresh.free();old_script=null;new_script=null
	print("FOREGROUND_HELPER_DIFFERENTIAL checks=%d failures=%d"%[checks,failures.size()])
	finish.call_deferred()
func finish() -> void:
	quit(0 if failures.is_empty() else 1)
