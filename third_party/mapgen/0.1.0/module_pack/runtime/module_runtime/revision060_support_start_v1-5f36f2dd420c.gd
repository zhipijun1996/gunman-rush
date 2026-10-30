extends Node
var player: PlayerController
var platform: ModuleMovingPlatform
var scope
var started:=false
var events: Array=[]
func setup(p: ModuleMovingPlatform,controller: PlayerController,context) -> void:
 platform=p;player=controller;scope=context;process_physics_priority=1050;p.bind_bell_control()
func _physics_process(_delta: float) -> void:
 if started or not player.active or not scope.lifetime.active:return
 if not player.motor.is_on_floor():return
 for i: int in player.motor.get_slide_collision_count():
  var contact: KinematicCollision2D=player.motor.get_slide_collision(i)
  if contact.get_collider()==platform and contact.get_normal().y<-.5:
   started=true;platform.set_motion_running(true);events.append({'type':'real_support_starts_motion','frame':scope.frame,'id':str(platform.definition.platform_id),'shots':player.action_resources.shot_charges,'clock':platform.motion_clock});return
