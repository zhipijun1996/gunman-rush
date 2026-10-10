extends RefCounted
## Real ModuleLab consumer integration; explicit position changes are state fixtures.
const DEMO := preload("res://scenes/demo/demo.tscn")
var tree: SceneTree
var check: Callable
func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	var app: DemoApp = DEMO.instantiate()
	tree.root.add_child(app)
	await idle_frames(2)
	var meta := app.meta.snapshot().duplicate(true)
	app._open_module_lab()
	await idle_frames(6)
	var lab := app._lab
	check.call(lab.request_module(&"windchime_trial"), "ModuleLab exposes an explicit windchime practice selection")
	await idle_frames(6)
	var trial: ModuleShotLatchTrial = lab.get("shot_latch_trial")
	check.call(trial != null and lab.ready_for_play, "windchime ModuleLab instantiates the real local switch consumer")
	if trial == null:
		app.queue_free()
		await idle_frames(2)
		return
	var entry_button: Button
	for node: Button in lab.find_children("*", "Button", true, false):
		if node.text == "WINDCHIME TRIAL":
			entry_button = node
	check.call(entry_button != null and entry_button.position == Vector2(1080,328), "dedicated windchime button preserves existing eight-button toolbar positions")
	check.call(not trial.all_open() and not lab.finished, "new windchime attempt begins with both solid doors closed")
	lab.controller.router.request_action(&"shoot_release", (trial.latches[0].bell_position-lab.player.position).normalized())
	await idle_frames(24)
	check.call(trial.latches[0].is_open and trial.latches[0].open_count==1, "actual App router projectile hits first practice bell and opens its linked door")
	var same_trial := trial
	lab.policy.clock += 2.0
	check.call(submit_damage(lab,&"windchime_return",1.0), "windchime practice submits real environmental damage to shared policy")
	lab.policy.resolve_batch()
	check.call(trial==same_trial and trial.latches[0].is_open and not trial.latches[1].is_open and lab.controller.actor_resources.health.current==4.0, "environmental return preserves partly opened switch state and spent health")
	lab.controller.router.request_action(&"shoot_release",Vector2.UP)
	await idle_frames(2)
	var second := trial.latches[1]
	var pending := {"event_id":"pause_pending_fixture", "amount":1.0, "session_id":lab.controller.session_id, "shot_id":lab.controller.shoot_ability._shot_serial, "source_faction":&"player", "source_actor_id":lab.player.get_instance_id(), "target_actor_id":second.receiver.actor_id, "target_epoch":second.health.epoch}
	check.call(second.receiver.receive_damage(pending), "pause cancellation fixture queues an eligible switch request before opening")
	lab.toggle_pause()
	await idle_frames(2)
	check.call(tree.paused and not second.is_open and lab.controller.shoot_ability.get_projectiles().is_empty(), "pause cancels old real projectiles and queued switch work without opening door")
	lab.menu.close_panel()
	await idle_frames(2)
	check.call(not second.is_open, "resume does not replay a cancelled switch opening")
	var token := lab.lifetime.token()
	var old_trial_id := trial.get_instance_id()
	lab.restart_module()
	await idle_frames(6)
	trial = lab.get("shot_latch_trial")
	check.call(trial.get_instance_id() != old_trial_id and not trial.all_open() and not lab.lifetime.accepts(token), "explicit Retry creates closed switch instances and invalidates old trial lifetime")
	lab.player.position = lab.module.world_exit()
	lab.player.reset_motion()
	await idle_frames(4)
	check.call(not lab.finished, "exit position alone cannot clear practice before opening both gates")
	lab.leave_lab()
	await idle_frames(4)
	check.call(app._lab==null and app.meta.snapshot()==meta and app.director.state==DemoRunDirector.State.HOME, "leaving windchime practice preserves Run and permanent progress")
	app._open_module_lab()
	await idle_frames(6)
	lab = app._lab
	lab.request_module(&"windchime_trial")
	await idle_frames(6)
	trial = lab.get("shot_latch_trial")
	lab.controller.router.request_action(&"shoot_release",Vector2.UP)
	await idle_frames(2)
	second=trial.latches[1]
	pending={"event_id":"fatal_pending_fixture", "amount":1.0, "session_id":lab.controller.session_id, "shot_id":lab.controller.shoot_ability._shot_serial, "source_faction":&"player", "source_actor_id":lab.player.get_instance_id(), "target_actor_id":second.receiver.actor_id, "target_epoch":second.health.epoch}
	check.call(second.receiver.receive_damage(pending), "fatal cancellation fixture queues an eligible latch request")
	lab.policy.clock += 2.0
	check.call(submit_damage(lab,&"windchime_fatal",99.0), "fatal windchime damage uses actual shared frame policy")
	lab.policy.resolve_batch()
	check.call(not lab.lifetime.active and not second.is_open and lab.controller.shoot_ability.get_projectiles().is_empty(), "same-frame fatal damage cancels projectiles and pending latch before deferred opening")
	await idle_frames(4)
	check.call(app._lab==null and app.meta.snapshot()==meta, "fatal windchime attempt returns Home without any permanent settlement")
	app.queue_free()
	await idle_frames(2)
func idle_frames(count:int) -> void:
	for _index:int in count:
		await tree.physics_frame
func submit_damage(lab:ModuleLab,id:StringName,amount:float) -> bool:
	var request:=DamageRequest.new()
	request.token=lab.lifetime.token()
	request.actor_epoch=lab.lifetime.actor_epoch
	request.health_epoch=lab.controller.actor_resources.health.epoch
	request.target_id=&"player"
	request.source_id=id
	request.event_id=id
	request.amount=amount
	request.kind=DamageRequest.Kind.ENVIRONMENT
	return lab.policy.submit(request)
