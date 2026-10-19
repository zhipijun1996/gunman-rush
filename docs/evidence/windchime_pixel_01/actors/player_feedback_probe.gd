extends SceneTree
var checks := 0
var failures := 0
func expect(ok: bool, text: String) -> void:
 checks+=1
 if not ok: failures+=1;printerr("FAIL "+text)
func _init() -> void: run.call_deferred()
func run() -> void:
 var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
 root.add_child(player)
 player.process_mode=Node.PROCESS_MODE_DISABLED
 var controller := player.get_node("Controller") as PlayerController
 var visual := PixelPlainsActor.new()
 visual.motor=player;visual.controller=controller;player.add_child(visual)
 var health := controller.actor_resources.health
 var before_position := player.position
 var collision := (player.get_node("CollisionShape2D") as CollisionShape2D).shape
 var before_health := health.current
 expect(not visual._dead and visual._hurt_remaining==0,"initial living presentation")
 controller.active=false;visual._process(.01)
 expect(not visual._dead,"inactive menu is not death")
 var rejected := health.apply_damage(ActorResourceRequest.new(&"bad_epoch",health.epoch-1,1,health.get_instance_id()))
 expect(not rejected.accepted() and visual._hurt_remaining==0,"rejected damage produces no flash")
 var request := ActorResourceRequest.new(&"accepted_damage",health.epoch,1,health.get_instance_id())
 var hit := health.apply_damage(request)
 expect(hit.status==ActorResourceResult.Status.APPLIED and visual._hurt_remaining>0,"actual applied negative damage drives flash")
 expect(health.current==before_health-1,"visual does not alter damage")
 visual._process(.25)
 expect(visual._hurt_remaining==0,"bounded hit flash expires")
 var replay := health.apply_damage(request)
 expect(replay.status==ActorResourceResult.Status.REPLAY and visual._hurt_remaining==0,"receipt replay produces no flash")
 var healed := health.heal(ActorResourceRequest.new(&"actual_heal",health.epoch,1,health.get_instance_id()))
 expect(healed.accepted() and visual._hurt_remaining==0,"healing produces no damage flash")
 var terminal := health.apply_damage(ActorResourceRequest.new(&"actual_terminal",health.epoch,health.current,health.get_instance_id()))
 expect(terminal.snapshot.terminal and visual._dead and visual._hurt_remaining==0,"actual terminal owns death pose")
 visual._process(.3)
 expect(visual._dead and visual._death_age>0,"terminal remains death while inactive")
 controller.reset_at(before_position)
 visual._process(.01)
 expect(not visual._dead and visual._death_age==0,"real health reset clears death pose")
 expect(player.position==before_position and (player.get_node("CollisionShape2D") as CollisionShape2D).shape==collision,"visual never changes Motor position/collision")
 player.free()
 await process_frame
 print("PIXEL_PLAYER_FEEDBACK checks=%d failures=%d"%[checks,failures])
 quit(0 if failures==0 else 1)
