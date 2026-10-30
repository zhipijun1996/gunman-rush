extends "module_loader_revision058_v1-7832dcbdd03b.gd"
## Select the original API's explicit any-side receiver mode before binding.
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
 var original_latches: Array=content.latches
 content.latches=content.latches.duplicate(true)
 for spec: Dictionary in content.latches:
  if spec.get("return_access_side_policy","")=="any":spec.erase("return_access")
 var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
 content.latches=original_latches
 if result.ok:
  for spec: Dictionary in content.latches:
   if spec.get("return_access_side_policy","")!="any":continue
   for latch: ShotLatch in cells.latches:
    if str(latch.link_id)==str(spec.id):latch.add_access_bell(Vector2(spec.return_access[0],spec.return_access[1]),false,false)
 return result
