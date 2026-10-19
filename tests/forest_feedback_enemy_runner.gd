extends "res://tests/forest_depth_enemy_runner.gd"
## New behavior controls only. Fixture evidence is never full-region admission.
var swing_frames: Array[Dictionary]=[]
var diagnostic: Dictionary={}
var feedback_checks: Array[Dictionary]=[]
func check(ok: bool,label: String) -> void:
	feedback_checks.append({"index":feedback_checks.size()+1,"label":label,"passed":ok})
	super.check(ok,label)
func run() -> void:
	await fixture(Vector2(250,282))
	var beetle:=enemy("forest_bark_beetle",Vector2(100,288))
	check(beetle.definition.is_valid() and beetle.attack_behavior is ForestBarkBeetleBehavior,"beetle authored definition and real dispatcher")
	controller.router.request_action(&"shoot_release",Vector2.LEFT)
	await frames(14)
	check(beetle.health.current==3 and (beetle.damageable as ForestBarkDamageable).blocked_count>0,"actual front projectile is stopped by bark shield")
	check(events.any(func(row: Dictionary)->bool:return row.kind=="accepted_shot"),"front control includes accepted Router shot")
	diagnostic.front_after={"player":[player.position.x,player.position.y],"home":[beetle.attack_behavior.home.x,beetle.attack_behavior.home.y],"distance_from_home":player.position.distance_to(beetle.attack_behavior.home),"activation_range":beetle.definition.activation_range,"can_engage":beetle.attack_behavior._can_engage()}
	await shield_contract_cases(beetle)
	# The front shot has real recoil. Test engagement in a fresh observation
	# fixture, rather than assuming that the shooter stayed in activation range.
	await fixture(Vector2(220,282))
	beetle=enemy("forest_bark_beetle",Vector2(100,288))
	var preview:=await wait_state(beetle.attack_behavior,&"telegraph")
	check(preview,"fresh observation sees beetle preannounce real committed charge")
	var direction:=beetle.brain.direction
	var before:=beetle.motor.global_position
	var goal:=beetle.attack_behavior.attack_goal
	var attack_seen:=false
	for i: int in 80:
		await frames(1)
		attack_seen=attack_seen or beetle.attack_behavior.state==&"attack"
	diagnostic.preview={"seen":preview,"attack_seen":attack_seen,"ledger":(beetle.attack_behavior as ForestBarkBeetleBehavior).ledger.duplicate(true),"before":[before.x,before.y],"after":[beetle.motor.position.x,beetle.motor.position.y],"goal":[goal.x,goal.y],"player":[player.position.x,player.position.y]}
	check(preview and attack_seen and not (beetle.attack_behavior as ForestBarkBeetleBehavior).ledger.is_empty() and beetle.motor.global_position.distance_to(before)>20 and beetle.brain.direction==direction and beetle.attack_behavior.attack_goal==goal,"observed telegraph leads to actual fixed-goal charge, not patrol movement")
	await fixture(Vector2(-50,282))
	beetle=enemy("forest_bark_beetle",Vector2(100,288))
	await shoot_to_death(beetle)
	check(beetle.health.terminal,"actual rear projectiles kill same full-health bark beetle")
	check((beetle.damageable as ForestBarkDamageable).blocked_count==0,"rear ordinary shooting is not armored")
	await fixture(Vector2(100,110))
	beetle=enemy("forest_bark_beetle",Vector2(100,288))
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await frames(14)
	check(beetle.health.current<3,"actual descending projectile damages unplated top")
	await fixture(Vector2(-200,282))
	var pod:=enemy("forest_swing_pod",Vector2(70,160))
	var swing:=pod.attack_behavior as ForestSwingPodBehavior
	check(pod.definition.is_valid() and swing!=null,"swing pod authored definition and real dispatcher")
	var minimum:=pod.motor.position.x
	var maximum:=minimum
	var min_y:=pod.motor.position.y
	var turns:=0
	for i: int in 288:
		await frames(1)
		minimum=minf(minimum,pod.motor.position.x);maximum=maxf(maximum,pod.motor.position.x);min_y=minf(min_y,pod.motor.position.y)
		if swing.state==&"turn":turns+=1
		swing_frames.append({"frame":i,"position":[pod.motor.position.x,pod.motor.position.y],"state":str(swing.state),"clock":swing.swing_clock})
	check(not swing.blocked and maximum-minimum>198 and min_y<91,"physical pendulum traverses broad curved orbit without collision snapping")
	check(turns>50,"slow readable turn phases provide catch windows")
	var clock:=swing.swing_clock
	paused=true
	for i: int in 8:await process_frame
	check(swing.swing_clock==clock,"pause retains moving anchor phase")
	paused=false
	var saved:=swing.depth_snapshot()
	check(swing.restore_depth_state(saved),"swing phase round-trip uses existing local persistence interface")
	var invalid:=saved.duplicate(true);invalid.clock=INF
	check(not swing.restore_depth_state(invalid) and swing.swing_clock==clock,"invalid nonfinite swing save rejected atomically")
	await fixture(Vector2(0,282))
	pod=enemy("forest_swing_pod",Vector2(170,160))
	var caught:=false
	controller.router.request_action(&"grapple",(pod.motor.global_position-player.global_position).normalized())
	for i: int in 40:
		await frames(1)
		caught=caught or controller.traversal.hook_target==pod.motor
	check(caught,"real grapple projectile catches moving pendulum body as live anchor")
	await fixture(Vector2(-200,282))
	pod=enemy("forest_swing_pod",Vector2(70,160))
	swing=pod.attack_behavior as ForestSwingPodBehavior
	slab(Rect2(110,40,30,180))
	await frames(120)
	check(swing.blocked and pod.motor.position.x<110,"real trunk obstruction stops swing on near side")
	var stopped:=pod.motor.position
	await frames(60)
	check(pod.motor.position==stopped,"blocked pendulum never teleports or retries through trunk")
	await cleanup()
	var output:="res://build/forest_feedback/enemies01"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):output=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"local actual actors Router projectile policy; not formal map admission or user fun acceptance","assertions":assertions,"failures":failures,"events":events,"swing_frames":swing_frames,"diagnostic":diagnostic,"checks":feedback_checks},"  "));file.close()
	print("FOREST FEEDBACK ENEMIES: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures==0 else 1)

func shield_contract_cases(beetle: EnemyActor) -> void:
	var receiver:=beetle.damageable as ForestBarkDamageable
	var hp_before:=beetle.health.current
	var feedback: Array[String]=[]
	var commits: Dictionary={"count":0}
	receiver.shield_contact.connect(func(context: Dictionary)->void:feedback.append(str(context.get("event_id",""))))
	var committed: Callable=func()->void:commits.count+=1
	var base: Dictionary={"event_id":"shield-contract-valid","amount":1.0,"source_actor_id":player.get_instance_id(),"target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"source_faction":&"player","hit_direction":Vector2(-beetle.brain.direction,0),"on_committed":committed}
	check(not receiver.receive_damage(base) and feedback.size()==1,"eligible front block emits exactly one shield response")
	check(not receiver.receive_damage(base) and feedback.size()==1,"duplicate blocked packet emits no second shield response")
	var replay:=base.duplicate();replay.hit_direction=-base.hit_direction
	check(not receiver.receive_damage(replay) and feedback.size()==1,"same blocked event cannot replay from rear to bypass shield")
	var invalid:=base.duplicate();invalid.event_id="shield-contract-stale";invalid.target_epoch=receiver.damage_epoch+1
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"stale epoch produces neither damage nor shield feedback")
	invalid=base.duplicate();invalid.event_id="shield-contract-faction";invalid.source_faction=receiver.faction
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"same-faction packet produces no shield feedback")
	invalid=base.duplicate();invalid.event_id="shield-contract-negative";invalid.amount=-1.0
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"negative amount produces no shield feedback")
	invalid=base.duplicate();invalid.event_id="shield-contract-self";invalid.source_actor_id=receiver.actor_id
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"self-source packet produces no shield feedback")
	invalid=base.duplicate();invalid.event_id="shield-contract-target";invalid.target_actor_id=receiver.actor_id+1
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"wrong target actor produces no shield feedback")
	invalid=base.duplicate();invalid.event_id=""
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"empty event produces no shield feedback")
	invalid=base.duplicate();invalid.event_id="shield-contract-nonfinite";invalid.amount=INF
	check(not receiver.receive_damage(invalid) and feedback.size()==1,"nonfinite amount produces no shield feedback")
	await frames(2)
	check(beetle.health.current==hp_before and commits.count==0,"blocked and invalid packets create no health or committed recovery transaction")
	diagnostic.shield_contract={"scope":"direct receiver lifecycle negative controls; actual gun front/back/top controls remain separate","feedback":feedback,"commits":commits.count,"hp_before":hp_before,"hp_after":beetle.health.current}
