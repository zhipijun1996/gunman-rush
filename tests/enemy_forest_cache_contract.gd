extends RefCounted
## Strict finite cached-vs-frozen5b deformation comparison, not a benchmark.
## No Actor, clocks, AI or render callbacks are advanced by this helper.
const SOURCE_A: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/beetle.png")
const SOURCE_B: Texture2D = preload("res://assets/forest_bible_v2/native/fine_32/seed_sentry.png")
const KINDS := [&"forest_lantern",&"forest_seed_sentry",&"forest_swing_pod",&"forest_bark_beetle",&"forest_crossbranch",&"forest_thread_spider",&"forest_bible_weaver"]
const BOUNDS := [Rect2(-18,-15,36,30),Rect2(-16.5,-19.5,33,39),Rect2(-13.5,-16.5,27,33),Rect2(-18,-10.5,36,24),Rect2(-18,-18.5,36,36),Rect2(-16,-16,32,32)]
const REFERENCE_DEFORM_SHA := "4d71240973cbf4458c79e5e64724a490118f9b7e812abfc2fb48ad3a78e7258d"
const REFERENCE_PREPARE_SHA := "abd088dfddbca8ab11e2456dc5bcc4e188ba80d24a6809177f0a9213e7502631"
var checks := 0
var failures: Array[String] = []
var compared_cases := 0
var compared_vertices := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func original_method(text: String,name: String) -> String:
	var start := text.find("func "+name+"(")
	if start < 0: return ""
	var end := text.find("\nfunc ",start+1)
	return text.substr(start,end-start if end>=0 else -1).strip_edges()

func layout(bounds: Rect2,variation: int) -> Array[Dictionary]:
	var joints: Array[Dictionary] = []
	if variation==5: return joints
	for index: int in 5:
		var region:=Rect2(bounds.position+Vector2(index*bounds.size.x/5.0,0),Vector2(bounds.size.x/5.0,bounds.size.y))
		var pivot:=region.get_center()+Vector2(0,index-2)
		var margin:=Vector2(4.5,4.5)
		if variation==1: region.position+=Vector2(.75,-.25)
		elif variation==2: margin+=Vector2(1.25,.25)
		elif variation==3: pivot+=Vector2(1.25,-.50)
		elif variation==4: region=Rect2(bounds.end+Vector2(100+index*20,100),Vector2(5,5))
		joints.append({"region":region,"margin":margin,"pivot":pivot,"angle":0.0})
	return joints

func compare_pose(motion: ForestMotion02,kind: StringName,foot_y: float,angle: float,label: String) -> void:
	var joints: Array[Dictionary]=motion.get("_joints")
	for index: int in joints.size(): joints[index].angle=angle*(1.0 if index%2==0 else -1.0)
	motion.call("_prepare_influences",kind,foot_y)
	var points: PackedVector2Array=motion.get("_mesh_points")
	var original:=PackedVector2Array()
	var cached:=PackedVector2Array()
	original.resize(points.size())
	cached.resize(points.size())
	for index: int in points.size():
		original[index]=motion.call("_deform_connected",points[index],kind,foot_y)
		cached[index]=motion.call("_deform_cached",index)
	compared_cases+=1
	compared_vertices+=points.size()
	check(original.to_byte_array()==cached.to_byte_array(),label+" strict Vector2 bytes match frozen5b")

func run() -> Dictionary:
	checks=0
	failures.clear()
	compared_cases=0
	compared_vertices=0
	var source:=FileAccess.get_file_as_string("res://game/enemies/presentation/forest_motion_02.gd")
	check(original_method(source,"_deform_connected").sha256_text()==REFERENCE_DEFORM_SHA,"original5b reference math is immutable; changing both paths cannot self-pass")
	var preparation:=original_method(source,"_prepare_mesh").replace("\n\t_influence_ready = false","")
	check(preparation.sha256_text()==REFERENCE_PREPARE_SHA,"original topology/UV/grid preparation retained except cache invalidation")
	check(ForestMotion02.GRID==16 and ForestMotion02.MOTION_GAIN==0.35,"original finite grid and gain retained")
	var motion:=ForestMotion02.new()
	if not motion.has_method("_prepare_influences") or not motion.has_method("_deform_cached"):
		check(false,"cached production methods are present")
		motion.dispose()
		return result()
	for texture: Texture2D in [SOURCE_A,SOURCE_B]:
		for kind: StringName in KINDS:
			var index: int=KINDS.find(kind)
			var bounds: Rect2=BOUNDS[mini(index,5)]
			motion.call("_prepare_mesh",texture,bounds)
			check(not motion.get("_influence_ready"),String(kind)+" texture/bounds rebuild invalidates influence cache")
			for variation: int in 6:
				motion.set("_joints",layout(bounds,variation))
				var feet: Array=[8.0,12.0,18.0] if kind==&"forest_bark_beetle" else [18.0]
				for foot_y: float in feet:
					for angle: float in [-.80,-.42,-.00000001,0.0,.00000001,.42,.80]:
						compare_pose(motion,kind,foot_y,angle,"%s/variation%s/foot%s/angle%s"%[kind,variation,foot_y,angle])
	# Keep layout and texture fixed while changing only kind and foot. This
	# independently catches stale masks/clamps hidden by a bounds rebuild.
	var fixed:=Rect2(-18,-10.5,36,24)
	motion.call("_prepare_mesh",SOURCE_A,fixed)
	motion.set("_joints",layout(fixed,0))
	for kind: StringName in KINDS:
		compare_pose(motion,kind,12.0,.31,"stable layout/kind "+String(kind))
	for foot_y: float in [14.499999,14.5,14.500001]:
		compare_pose(motion,&"forest_bark_beetle",foot_y,-.31,"exact foot-clamp boundary "+str(foot_y))
	motion.dispose()
	check(not motion.get("_influence_ready") and (motion.get("_influence_indices") as Array).is_empty() and (motion.get("_influence_weights") as Array).is_empty(),"dispose releases influence layout and static weights")
	motion.call("_prepare_mesh",SOURCE_B,fixed)
	motion.set("_joints",layout(fixed,3))
	compare_pose(motion,&"forest_bark_beetle",12.0,.19,"fresh layout after disposal")
	check(compared_cases>=756 and compared_vertices>=218484,"complete original finite parity envelope exercised")
	motion.dispose()
	return result()

func result() -> Dictionary:
	return {"scope":"finite CPU math byte parity and cache invalidation only; no early-cull GPU or route-performance acceptance","checks":checks,"failures":failures.duplicate(),"compared_cases":compared_cases,"compared_vertices":compared_vertices,"baseline_commit":"5b083938ea9f2722fe6c44896914f9d2d198e87b","baseline_deform_sha":REFERENCE_DEFORM_SHA}
