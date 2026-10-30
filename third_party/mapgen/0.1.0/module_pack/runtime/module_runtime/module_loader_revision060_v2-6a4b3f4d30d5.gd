extends "module_loader_ideas_v2-14f1ba7244c3.gd"
const APPROVED060=preload('revision060_binding_v2-78821430f8a2.gd')
const INTERCEPT060=preload('revision059_interception_observer_v1-45262dc58049.gd')
var approved060
var interception060
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String='') -> Dictionary:
 var original:=content;content=APPROVED060.ordinary(original);var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id);content=original
 if not result.ok:return result
 approved060=APPROVED060.new();add_child(approved060);approved060.setup(original,self,player,scope,cells,rewards);interception060=INTERCEPT060.new();add_child(interception060);interception060.setup(cells.enemies,scope);return result
func snapshot() -> Dictionary:
 var result:=super.snapshot()
 if is_instance_valid(approved060):result.approved_hq=approved060.snapshot()
 if is_instance_valid(interception060):result.interceptions=interception060.events.duplicate(true)
 return result
