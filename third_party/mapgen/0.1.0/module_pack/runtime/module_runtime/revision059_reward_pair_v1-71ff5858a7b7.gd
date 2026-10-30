extends "pair_latch_v3-33307e6c887e.gd"
## A real successful reward transaction schedules the original guarded pair.
var committed_reward: Dictionary={}
var swapped:=false
func _register_shot(_direction: Vector2,_shot_id: int) -> void:pass
func _receive_projectile(_hit: Dictionary) -> bool:return false
func accept_reward(result: SimpleRewardResult) -> void:
 if result.status!=SimpleRewardResult.Status.COMMITTED or result.amount_applied<=0 or not committed_reward.is_empty():return
 committed_reward={'id':str(result.event_id),'token':lifetime.token(),'session':controller.session_id,'health_epoch':health.epoch,'request_epoch':_request_epoch}
func _physics_process(delta: float) -> void:
 super._physics_process(delta)
 if not committed_reward.is_empty() and not swapped:_commit_open.call_deferred(committed_reward.duplicate())
func _commit_open(request: Dictionary) -> void:
 if swapped or committed_reward.is_empty() or request.get('id','')!=committed_reward.id:return
 super._commit_open(request)
 swapped=not open_a
func export_state() -> Dictionary:
 return {'schema':'approved-hq04-reward/v1','run_epoch':lifetime.epoch,'claimed':not committed_reward.is_empty(),'swapped':swapped,'reward_event':committed_reward.get('id','')}
func restore_state(value: Dictionary) -> bool:
 if value.get('schema','')!='approved-hq04-reward/v1' or value.get('run_epoch',-1)!=lifetime.epoch or not value.get('claimed',false) or str(value.get('reward_event','')).is_empty() or not committed_reward.is_empty():return false
 committed_reward={'id':value.reward_event,'token':lifetime.token(),'session':controller.session_id,'health_epoch':health.epoch,'request_epoch':_request_epoch}
 # Restoring is an explicit module load operation, before any player advances.
 if value.get('swapped',false):open_a=false;swapped=true;_apply_pair_state()
 return true
func _draw() -> void:
 if not is_instance_valid(paired_gate_body):return
 _draw_gate(gate_rect,.2 if open_a else 1.);_draw_gate(paired_gate_rect,1. if open_a else .2)
