class_name WindkeeperPressureProjectile
extends BossProjectile
## Real finite seed or supported ground wave; cancel ownership precedes contact.
var wave := false
var _attack_owner: WeakRef
var _owner_epoch := -1

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func bind_attack(owner: Node, epoch: int) -> void:
	_attack_owner = weakref(owner)
	_owner_epoch = epoch

func _owned() -> bool:
	if _attack_owner == null: return false
	var owner := _attack_owner.get_ref() as WindkeeperEncounter
	return is_instance_valid(owner) and owner.active and not owner.health.terminal and owner.attack_epoch == _owner_epoch

func advance(delta: float) -> void:
	if spent or not is_inside_tree() or delta <= 0 or not is_finite(delta): return
	if not _owned():
		dispose()
		return
	if wave:
		var next := global_position + direction * speed * delta
		var exclude: Array[RID] = []
		if is_instance_valid(_owner_body): exclude.append(_owner_body.get_rid())
		if _target is CollisionObject2D: exclude.append((_target as CollisionObject2D).get_rid())
		var support := PhysicsRayQueryParameters2D.create(next, next + Vector2(0, radius + 12), 1, exclude)
		if get_world_2d().direct_space_state.intersect_ray(support).is_empty():
			dispose()
			return
	super.advance(delta)

func advance_frozen_contact() -> void:
	if not _owned():
		dispose()
		return
	super.advance_frozen_contact()

func _emit_visual(point: Vector2, impact: bool) -> void:
	var owner := _attack_owner.get_ref() as Node if _attack_owner != null else null
	PlainsBossEffects.spawn(get_parent(),owner,point,&"wind",2,.28,Vector2.ONE*(1.0 if impact else .45))

func _draw() -> void:
	if wave:
		PlainsBossEffects.paint(self,&"wind",1,fposmod(_visual_age*10,1),Vector2.ZERO,Vector2(signf(direction.x),1)*radius/12.0)
	else:
		PlainsBossEffects.paint(self,&"wind",0,fposmod(_visual_age*10,1),Vector2.ZERO,Vector2.ONE,direction.angle())
