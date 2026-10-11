extends SceneTree
var failed := 0
var assertions := 0
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failed += 1
		printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var g := PlainsRegionGenerator.new()
	var tuning := PlayerTuning.load_default()
	corpus(g,tuning)
	for family: String in PlainsRegionGenerator.FAMILIES:
		var r := g.generate("region-"+family,tuning,false,family)
		check(r.ok,"family generates " + family)
		if r.ok: print("REGION ",family," areas=",r.manifest.areas.size()," fallback=",r.manifest.fallback_id)
	var fixed := g.generate("sample",tuning,true,"woven_layers")
	check(fixed.ok,"fixed 12 node sample validates")
	if fixed.ok: print("SAMPLE ",fixed.manifest.areas.size()," fallback=",fixed.manifest.fallback_id)
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("region-app"),"formal connected region starts")
	for i: int in 10: await physics_frame
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok,"formal uses region assembler")
	check(app.director.profile.is_valid(true) and app.director.stage_index == 1,"formal region profile")
	check(is_instance_valid(app.stage) and app.stage.exits.is_empty(),"no room progression exits")
	if app.stage is PlainsRegionStage:
		check(app.stage.generated.manifest.areas.size() in [20,23] and app.stage.generated.manifest.fallback_id.is_empty(),"normal automatic-family App must deliver randomized map, not fallback")
		check(app.stage.boss != null,"Boss exists from start without seven exits")
		check(app.controller.motor.tuning.max_jumps == 1 and app.controller.motor.tuning.max_air_shots == 2,"base action resources preserved")
		check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json())) != null,"formal region manifest JSON roundtrip")
	app.abandon_run()
	for i: int in 3: await physics_frame
	app.free()
	var trace = load("res://tests/plains_region_trace.gd").new()
	trace.tree = self
	trace.check = check
	if fixed.ok:
		await trace.journey(fixed.manifest,tuning,"tour")
		await trace.tutorial_return(fixed.manifest,tuning)
	var fallback:=g.verified_fallback("forced-fallback-proof",tuning)
	check(fallback.ok and fallback.manifest.fallback_id=="verified_exploration_region" and fallback.manifest.rewards.size()==4,"complete exploration fallback is reproducible")
	if fallback.ok:
		await trace.journey(fallback.manifest,tuning,"tour")
		await trace.adventure(fallback.manifest,tuning)
	for family: String in PlainsRegionGenerator.FAMILIES:
		var r:=g.generate("region-"+family,tuning,false,family)
		if r.ok:
			await trace.journey(r.manifest,tuning,"fast")
			await trace.journey(r.manifest,tuning,"growth")
			await trace.journey(r.manifest,tuning,"tour")
			await trace.adventure(r.manifest,tuning)
	print("REGION ASSERTIONS: ",assertions," FAILED: ",failed)
	quit(1 if failed else 0)

func corpus(g: PlainsRegionGenerator,tuning: PlayerTuning) -> void:
	var summary:= {"version":PlainsRegionGenerator.VERSION,"seeds":150,"families":{},"fallbacks":0,"travel_signatures":0}
	var travels: Dictionary={}
	for family: String in PlainsRegionGenerator.FAMILIES:
		var signatures: Dictionary={}
		var cycles_min:=100
		var forks_min:=100
		for i: int in 50:
			var seed_value: String="corpus/%s/%s" % [family,i]
			var r:=g.generate(seed_value,tuning,false,family)
			check(r.ok,"bounded corpus generation " + seed_value)
			if not r.ok: continue
			var m: Dictionary=r.manifest
			check(m.family==family and m.fallback_id.is_empty(),"requested distinct topology is delivered without fallback")
			if not m.fallback_id.is_empty(): summary.fallbacks+=1
			check(m.areas.size() in [20,23],"random map within requested 18–24 node scope")
			check(g.validate(JSON.parse_string(JSON.stringify(m)),tuning),"entire serialized map replay validates")
			var n:=g.generate(seed_value,tuning,false,family)
			check(m.manifest_hash==n.manifest.manifest_hash,"all separated random streams reproduce")
			var open_edges: Array=[]
			for e: Dictionary in m.connections:
				if e.condition=="open": open_edges.append([e.a,e.b,e.bidirectional])
			var graph_signature:=JSON.stringify(open_edges)
			signatures[graph_signature]=true
			var trace=load("res://tests/plains_region_trace.gd").new()
			var assembler:=PlainsRegionAssembler.new()
			assembler.manifest=m
			trace.stage=assembler
			var path: Array=trace.path_to("area_0_1",str(m.prep_id))
			var journey: Array=[]
			for step: Dictionary in path: journey.append([step.edge.a,step.edge.b,step.forward])
			travels[JSON.stringify(journey)]=true
			check(not path.is_empty(),"Boss prep reachable before any reward/shop/key/enemy-clear")
			assembler.free()
			cycles_min=mini(cycles_min,g._cycles(m))
			forks_min=mini(forks_min,m.areas.filter(func(a: Dictionary): return g._degree(m,a.id)>=3).size())
			check(m.rewards.size()==4 and m.rewards.filter(func(c: Dictionary): return c.tier=="high" or c.tier=="region_top").size()==2,"reward strong-item count is independent of map scale")
			if i==0:
				var file:=FileAccess.open("res://docs/evidence/plains_connected_region/"+family+".json",FileAccess.WRITE)
				file.store_string(JSON.stringify(m,"  ",true))
			summary.families[family]={"graph_signatures":signatures.size(),"minimum_cycles":cycles_min,"minimum_forks":forks_min}
		check(signatures.size()>=10,"actual connection topology varies within " + family)
	check(travels.size()>=12,"seed changes actual early-Boss itinerary beyond cosmetic/hash variation")
	summary.travel_signatures=travels.size()
	summary.automatic_seeds=50
	summary.automatic_fallbacks=0
	var file:=FileAccess.open("res://docs/evidence/plains_connected_region/corpus.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  ",true))
	for i: int in 50:
		var r:=g.generate("automatic-family/%s" % i,tuning)
		check(r.ok and r.manifest.fallback_id.is_empty() and r.manifest.areas.size() in [20,23],"automatic family selection follows same reproducible stream schedule")
	# Rehashed cheating still fails: fake passage, removed collision, inflated reward.
	var original: Dictionary=g.generate("tamper",tuning).manifest
	for kind: String in ["geometry","connection","reward"]:
		var changed: Dictionary=original.duplicate(true)
		if kind=="geometry": changed.nodes[0].geometry.platforms[0][2]=1
		elif kind=="connection": changed.connections[0].b="windkeeper"
		else: changed.rewards[0].coins=9999
		changed.manifest_hash=g._hash(changed)
		check(not g.validate(changed,tuning),"rehashed forged " + kind + " rejected")
