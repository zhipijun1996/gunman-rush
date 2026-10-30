extends Node
## Read-only original EnemyAttackProjectile sweep; disposal signal supplies the receipt.
var enemies: Array[EnemyActor]=[]
var scope
var watched: Dictionary={}
var latest: Dictionary={}
var events: Array=[]
func setup(actors: Array[EnemyActor],context) -> void:
 enemies=actors;scope=context;process_physics_priority=-1
func _physics_process(delta: float) -> void:
 for actor: EnemyActor in enemies:
  if actor.attack_behavior==null:continue
  for projectile: EnemyAttackProjectile in actor.attack_behavior._projectiles:
   if not is_instance_valid(projectile) or projectile.spent:continue
   var id:=projectile.get_instance_id()
   if not watched.has(id):
    watched[id]=true;projectile.tree_exiting.connect(_disposed.bind(projectile,id));events.append({'type':'original_enemy_projectile_fired','frame':scope.frame,'event_id':str(projectile.event_id)})
   latest.erase(id)
   if projectile.remaining<=delta or not projectile.behavior._active() or not projectile.behavior.lifetime.accepts(projectile.token):continue
   var protected:=false
   for point: Vector2 in projectile.behavior.protected_points:
    if DemoContactEmitter.segment_intersects_bounds(projectile.global_position,projectile.global_position+projectile.direction*projectile.speed*delta,Rect2(point-Vector2.ONE*actor.definition.protected_radius,Vector2.ONE*actor.definition.protected_radius*2)):protected=true
   if protected:continue
   var query:=PhysicsShapeQueryParameters2D.new();query.shape=projectile._shape;query.transform=Transform2D(0,projectile.global_position);query.motion=projectile.direction*projectile.speed*delta;query.collision_mask=1;query.exclude=[actor.motor.get_rid()]
   var space:=projectile.get_world_2d().direct_space_state;var overlaps:=space.intersect_shape(query,8);var fraction:=0. if not overlaps.is_empty() else 1.
   if overlaps.is_empty():
    var cast:=space.cast_motion(query);fraction=cast[1] if cast.size()==2 else 1.
   if fraction>=1 and overlaps.is_empty():continue
   query.transform.origin+=query.motion*minf(1,fraction+.001);query.motion=Vector2.ZERO
   var hits:=overlaps if not overlaps.is_empty() else space.intersect_shape(query,8)
   if hits.is_empty() or not hits.all(func(hit: Dictionary):return hit.get('collider') is ModuleMovingPlatform):continue
   latest[id]={'type':'original_enemy_projectile_intercepted','frame':scope.frame,'event_id':str(projectile.event_id),'remaining_before':projectile.remaining,'platform_id':str(hits[0].collider.definition.platform_id),'point':[query.transform.origin.x,query.transform.origin.y],'original_circle_sweep':true,'protected_point_cancel':false}
func _disposed(projectile: EnemyAttackProjectile,id: int) -> void:
 if not latest.has(id) or not projectile.spent or projectile.remaining<=0:return
 var receipt: Dictionary=latest[id].duplicate();receipt.disposed=true;receipt.remaining_after=projectile.remaining;events.append(receipt);latest.erase(id)
