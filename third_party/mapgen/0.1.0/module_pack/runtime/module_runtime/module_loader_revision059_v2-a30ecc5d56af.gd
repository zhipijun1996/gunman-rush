extends "module_loader_ideas_v2-14f1ba7244c3.gd"
const APPROVED_HQ=preload('revision059_hq_binding_v2-573042013006.gd')
var approved_hq
var saved_state: Dictionary={}
func provide_saved_state(value: Dictionary) -> bool:
 if bound or not saved_state.is_empty() or value.get('schema','')!='approved-hq04-reward/v1' or not value.get('claimed',false) or str(value.get('reward_event','')).is_empty():return false
 saved_state=value.duplicate(true);return true
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String='') -> Dictionary:
 var original:=content.duplicate(true)
 if not saved_state.is_empty():
  if saved_state.get('run_epoch',-1)!=lifetime.epoch or not str(original.get('stable_id','')).contains('hq04'):return {'ok':false,'reason':'saved_reward_scope_mismatch'}
  original.approved_hq_saved_state=saved_state.duplicate(true)
 content=APPROVED_HQ.ordinary(original)
 if not saved_state.is_empty():content.reward_sites=[]
 var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id);content=original
 if not result.ok:return result
 approved_hq=APPROVED_HQ.new();add_child(approved_hq);approved_hq.setup(original,self,player,scope,cells,rewards)
 if not setup_error.is_empty():bound=false;return {'ok':false,'reason':setup_error}
 return result
func export_saved_state() -> Dictionary:
 if not bound:return {}
 for cell in approved_hq.custom:
  if cell.has_method('export_state'):return cell.export_state()
 return {}
func snapshot() -> Dictionary:
 var result:=super.snapshot()
 if is_instance_valid(approved_hq):result.approved_hq=approved_hq.snapshot();result.reward_state=export_saved_state()
 return result
