extends "res://tests/forest_depth_enemy_runner.gd"
## Local actual-input mechanism evidence; formal v15 traversal remains separate.
const STRANDS := [{"id":"upper","start":[100.0,220.0],"end":[160.0,220.0]},{"id":"lower","start":[160.0,250.0],"end":[160.0,290.0]}]
var weaver_checks: Array[Dictionary] = []
var weaver_cases: Array[Dictionary] = []
var phase_frames: Array[Dictionary] = []
var strategy_frames: Array[Dictionary] = []
var strategy_id := ""

func check(ok: bool,label: String) -> void:
	weaver_checks.append({"label":label,"passed":ok})
	super.check(ok,label)

func frames(count: int) -> void:
	for i: int in count:
		await super.frames(1)
		if strategy_id.is_empty() or enemies.is_empty(): continue
		var weaver := enemies[0].attack_behavior as ForestBibleWeaverBehavior
		if weaver == null: continue
		strategy_frames.append({"case":strategy_id,"tick":tick,"position":[player.global_position.x,player.global_position.y],"hp":controller.actor_resources.health.current,"state":str(weaver.state),"strand":weaver.strand_index,"active":weaver.line_active,"caught_fixed":controller.traversal.hook_target is GrappleAnchor,"serial":weaver._serial})

func make_weaver(at := Vector2.ZERO) -> EnemyActor:
	strategy_id = ""
	await fixture(Vector2(at.x,282))
	var spider := enemy("forest_bible_weaver",Vector2(270,282))
	check(spider.definition.is_valid() and spider.attack_behavior is ForestBibleWeaverBehavior,"new scene uses authored definition and shared actor dispatcher")
	check((spider.attack_behavior as ForestBibleWeaverBehavior).configure_strands(STRANDS),"both authored finite entrance strands configure")
	return spider

func wait_strand(weaver: ForestBibleWeaverBehavior,index: int,phase: StringName,limit := 900) -> bool:
	for i: int in limit:
		if weaver.strand_index == index and weaver.state == phase: return true
		await frames(1)
	return false

func local_snapshot_cases() -> void:
	var spider := await make_weaver()
	var weaver := spider.attack_behavior as ForestBibleWeaverBehavior
	var holds: Array[int] = []
	var previous_serial := -1
	var single_active := true
	var phases: Dictionary = {}
	for i: int in 1100:
		await frames(1)
		var key := "%s/%s" % [weaver.strand_index,weaver.state]
		if not phases.has(key):
			var saved := weaver.depth_snapshot()
			check(weaver.restore_depth_state(saved),"phase roundtrip " + key)
			check(weaver.depth_snapshot() == saved,"restoration retains selected entrance and per-cycle dedup " + key)
			var reloaded := ForestBibleWeaverBehavior.new()
			reloaded.configure(spider,controller,policy,life,&"forest_bible_weaver",[])
			var configured := reloaded.configure_strands(STRANDS)
			reloaded.state = weaver.state
			reloaded.state_time = weaver.state_time
			reloaded.cooldown = weaver.cooldown
			reloaded._serial = weaver._serial
			check(configured and reloaded.restore_depth_state(saved) and reloaded.depth_snapshot() == saved,"fresh local behavior restores bound phase " + key)
			check(reloaded._previous_player == player.global_position,"reload starts a fresh swept body origin " + key)
			reloaded.free()
			phases[key] = true
		phase_frames.append({"tick":tick,"strand":weaver.strand_index,"state":str(weaver.state),"state_time":weaver.state_time,"active":weaver.line_active,"serial":weaver._serial})
		single_active = single_active and weaver.line_active == (weaver.state == &"hold")
		if weaver.state == &"hold" and previous_serial != weaver._serial:
			holds.append(weaver.strand_index)
			previous_serial = weaver._serial
		if holds.size() == 3: break
	check(single_active,"only real hold owns the one active strand")
	check(holds == [0,1,0],"one spider alternates upper lower upper, rather than independent timers")
	check(phases.has("0/telegraph") and phases.has("1/telegraph") and phases.has("0/retract") and phases.has("1/retract"),"both entrances expose real warning and retraction phases")
	var intact := weaver.depth_snapshot()
	for key: String in ["version","strand_index","index_flip","strands","selected_id","start","end","phase","state_time","cooldown","serial","home","cycle_completed","completion_serial","hit_this_cycle","hit_serial"]:
		var corrupted := intact.duplicate(true)
		match key:
			"version": corrupted.version = 1
			"strand_index": corrupted.strand_index = 2
			"index_flip": corrupted.strand_index = 1-intact.strand_index
			"strands": corrupted.strands[0].start[0] += 1
			"selected_id": corrupted.selected_id = "lower" if intact.selected_id == "upper" else "upper"
			"start": corrupted.start[0] += 1
			"end": corrupted.end[0] += 1
			"phase": corrupted.phase = "telegraph" if intact.phase != "telegraph" else "hold"
			"state_time": corrupted.state_time += 0.01
			"cooldown": corrupted.cooldown += 0.01
			"serial": corrupted.serial += 1
			"home": corrupted.home[0] += 1
			"cycle_completed": corrupted.cycle_completed = "false"
			"completion_serial": corrupted.completion_serial += 1
			"hit_this_cycle": corrupted.hit_this_cycle = 1
			"hit_serial": corrupted.hit_serial += 1
		check(not weaver.restore_depth_state(corrupted) and weaver.depth_snapshot() == intact,"corrupted " + key + " rejected atomically")
	var previous_time := weaver.state_time
	weaver.state_time = INF
	check(not weaver.restore_depth_state(intact),"nonfinite outer phase debt rejected")
	weaver.state_time = previous_time
	var invalid := ForestBibleWeaverBehavior.new()
	invalid.actor = spider
	check(not invalid.configure_strands([STRANDS[0]]),"single line cannot impersonate two entrances")
	var reversed := [STRANDS[1],STRANDS[0]]
	check(not invalid.configure_strands(reversed),"swapped authored entrance identities rejected")
	for bad: Array in [[{"id":"upper","start":[0,0],"end":[151,0]},STRANDS[1]],[STRANDS[0],{"id":"lower","start":[0,250],"end":[0,257]}],[{"id":"upper","start":[0,INF],"end":[50,220]},STRANDS[1]]]:
		check(not invalid.configure_strands(bad) and not invalid.line_configured,"malformed length or nonfinite entrance cannot become active")
	invalid.free()
	weaver_cases.append({"id":"alternation_restore","holds":holds,"phases":phases.keys()})

func strategy_cases() -> void:
	var spider := await make_weaver()
	var weaver := spider.attack_behavior as ForestBibleWeaverBehavior
	check(await wait_strand(weaver,1,&"hold"),"occupied control observes real lower entrance hold")
	var before := controller.actor_resources.health.current
	strategy_id = "occupied_body"
	var start_tick := tick
	controller.router.set_move_axis(1)
	for i: int in 45:
		await frames(1)
		if controller.actor_resources.health.current < before: break
	var committed := weaver.depth_snapshot()
	check(weaver.state == &"hold" and committed.hit_this_cycle and weaver.restore_depth_state(committed),"already committed hold restores its per-cycle hit")
	await frames(3)
	var after_restore := events.filter(func(row: Dictionary)->bool:return row.kind == "policy_result" and row.target == "player" and row.tick >= start_tick and ":thread:" in str(row.event_id))
	check(after_restore.size() == 1,"restored hit cannot resubmit a duplicate line request")
	for i: int in 45:
		if player.global_position.x > 180: break
		await frames(1)
	controller.router.set_move_axis(0)
	await frames(8)
	var after := controller.actor_resources.health.current
	check(player.global_position.x > 180 and before-after == (spider.definition as ForestEnemyDefinition).line_damage,"ordinary body crossing of occupied lower entrance takes original policy damage")
	var once := events.filter(func(row: Dictionary)->bool:return row.kind == "policy_result" and row.target == "player" and row.tick >= start_tick and ":thread:" in str(row.event_id))
	check(once.size() == 1,"one shared serial causes one real line damage commit")
	weaver_cases.append({"id":"occupied_body","start_tick":start_tick,"end_tick":tick,"hp_before":before,"hp_after":after,"position":[player.global_position.x,player.global_position.y]})

	spider = await make_weaver()
	weaver = spider.attack_behavior as ForestBibleWeaverBehavior
	check(await wait_strand(weaver,1,&"telegraph"),"preview control observes actual lower warning")
	before = controller.actor_resources.health.current
	strategy_id = "preview_cross"
	start_tick = tick
	controller.router.set_move_axis(1)
	await frames(45)
	controller.router.set_move_axis(0)
	await frames(8)
	check(player.global_position.x > 180 and controller.actor_resources.health.current == before,"preview silk has no damage before real extension completes")
	weaver_cases.append({"id":"preview_cross","start_tick":start_tick,"end_tick":tick,"hp_before":before,"hp_after":controller.actor_resources.health.current,"position":[player.global_position.x,player.global_position.y]})

	spider = await make_weaver()
	weaver = spider.attack_behavior as ForestBibleWeaverBehavior
	check(await wait_strand(weaver,1,&"hold"),"wait strategy observes lower line before committing")
	before = controller.actor_resources.health.current
	strategy_id = "wait_retract"
	start_tick = tick
	check(await wait_strand(weaver,1,&"retract"),"wait strategy waits for actual retraction")
	controller.router.set_move_axis(1)
	await frames(45)
	controller.router.set_move_axis(0)
	await frames(8)
	check(player.global_position.x > 180 and controller.actor_resources.health.current == before and not spider.health.terminal,"waiting crosses the same entrance alive without damage or resource injection")
	weaver_cases.append({"id":"wait_retract","start_tick":start_tick,"end_tick":tick,"hp_before":before,"hp_after":controller.actor_resources.health.current,"position":[player.global_position.x,player.global_position.y]})

	spider = await make_weaver()
	weaver = spider.attack_behavior as ForestBibleWeaverBehavior
	check(await wait_strand(weaver,1,&"hold"),"side-fruit strategy observes actual lower closure")
	ring(Vector2(175,160))
	before = controller.actor_resources.health.current
	strategy_id = "fixed_fruit_bypass"
	start_tick = tick
	controller.router.request_action(&"grapple",(Vector2(175,160)-player.global_position).normalized())
	controller.router.set_move_axis(1)
	var caught := false
	var crossed := false
	for i: int in 90:
		await frames(1)
		caught = caught or controller.traversal.hook_target is GrappleAnchor
		if player.global_position.x > 195:
			crossed = true
			controller.router.set_move_axis(0)
			break
	check(caught and crossed and controller.actor_resources.health.current == before and not spider.health.terminal,"real fixed side fruit changes body height through the other entrance while retaining spider")
	weaver_cases.append({"id":"fixed_fruit_bypass","start_tick":start_tick,"end_tick":tick,"caught_fixed":caught,"crossed":crossed,"hp_before":before,"hp_after":controller.actor_resources.health.current,"position":[player.global_position.x,player.global_position.y]})

	spider = await make_weaver()
	weaver = spider.attack_behavior as ForestBibleWeaverBehavior
	before = controller.actor_resources.health.current
	strategy_id = "shoot_dead_pass"
	start_tick = tick
	await shoot_to_death(spider)
	check(spider.health.terminal and not weaver.line_active,"actual Router projectiles kill spider and remove its line")
	check(events.any(func(row: Dictionary)->bool:return row.kind == "policy_result" and row.target == "forest_bible_weaver" and row.hp == 0 and str(row.source).begins_with("player_projectile:")),"lethal outcome is a committed original projectile policy result")
	controller.router.set_move_axis(1)
	for i: int in 100:
		await frames(1)
		if player.global_position.x > 195: break
	controller.router.set_move_axis(0)
	check(player.global_position.x > 195 and controller.actor_resources.health.current == before,"dead spider leaves legal ordinary supported passage")
	weaver_cases.append({"id":"shoot_dead_pass","start_tick":start_tick,"end_tick":tick,"dead":spider.health.terminal,"hp_before":before,"hp_after":controller.actor_resources.health.current,"position":[player.global_position.x,player.global_position.y]})

func body_edge_case() -> void:
	var spider := await make_weaver()
	var weaver := spider.attack_behavior as ForestBibleWeaverBehavior
	# The real grounded body grazes a finite endpoint although its center stays
	# below that segment. This is a physical walking control, not a moved player.
	var edge_strands := [{"id":"upper","start":[100,200],"end":[160,200]},{"id":"lower","start":[100,250],"end":[100,260]}]
	check(weaver.configure_strands(edge_strands),"finite body-edge control configures without extending its center line")
	check(await wait_strand(weaver,1,&"hold"),"body-edge control observes actual lower hold")
	var before := controller.actor_resources.health.current
	var start_tick := tick
	strategy_id = "body_edge"
	controller.router.set_move_axis(1)
	await frames(27)
	controller.router.set_move_axis(0)
	await frames(2)
	check(player.global_position.x > 115 and player.global_position.y > 260 and before-controller.actor_resources.health.current == (spider.definition as ForestEnemyDefinition).line_damage,"real body endpoint grazing hits while center path never touches finite strand")
	weaver_cases.append({"id":"body_edge","start_tick":start_tick,"end_tick":tick,"hp_before":before,"hp_after":controller.actor_resources.health.current,"position":[player.global_position.x,player.global_position.y]})

func lifecycle_cases() -> void:
	var spider := await make_weaver()
	var weaver := spider.attack_behavior as ForestBibleWeaverBehavior
	check(await wait_strand(weaver,0,&"hold"),"lifecycle control reaches actual upper hold")
	var saved := weaver.depth_snapshot()
	var clock := weaver.state_time
	paused = true
	for i: int in 8: await process_frame
	check(weaver.state_time == clock and weaver.depth_snapshot() == saved,"pause preserves exact strand phase")
	paused = false
	life.invalidate_actor()
	await frames(1)
	check(not weaver.line_active and weaver.state == &"recovery","actor epoch cancels obsolete strand token")
	check(await wait_strand(weaver,0,&"hold"),"interrupted cycle resumes with same entrance and complete warning")
	controller.active = false
	await frames(1)
	check(not weaver.line_active and weaver.state == &"recovery","inactive target removes active web")
	controller.active = true
	check(await wait_strand(weaver,0,&"hold"),"reactivation retains interrupted entrance")
	# Explicit source-relocation counterfactual, never used as passage evidence.
	spider.motor.position += Vector2(2,0)
	await frames(1)
	check(not weaver.line_active and weaver.state == &"recovery","moving host away cannot leave detached old entrance damage")
	check(weaver._token == null,"host displacement revokes the original line token")
	spider.motor.position -= Vector2(2,0)
	check(await wait_strand(weaver,0,&"hold"),"returned host repeats full warning on the interrupted entrance")
	var old_token := weaver._token
	var body := spider.motor
	world.remove_child(body)
	check(not weaver.line_active and weaver._token == null,"actual host removal cancels the inherited damage token immediately")
	enemies.clear()
	contacts.clear()
	body.free()
	life.end()
	check(not life.accepts(old_token),"ended scope cannot accept a pre-unload line token")
	weaver_cases.append({"id":"lifecycle","pause_preserved":true,"epoch_cancelled":true,"inactive_cancelled":true,"moved_cancelled":true,"unload_cancelled":true})

func run() -> void:
	await local_snapshot_cases()
	await strategy_cases()
	await body_edge_case()
	await lifecycle_cases()
	await cleanup()
	var output := "res://build/region_bible_v2/ecology/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"local real actors Router projectile policy, not formal v15 route admission","assertions":assertions,"failures":failures,"checks":weaver_checks,"cases":weaver_cases,"phase_frames":phase_frames,"strategy_frames":strategy_frames,"events":events},"  "))
	file.close()
	print("FOREST BIBLE WEAVER: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
