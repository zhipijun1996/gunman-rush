extends "module_loader_revision061_v2-daa7e5eceb9f.gd"
const MOUNT062=preload('revision062_mount_v1-dfd8c0d4e232.gd')
func bind_player(player: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,wallet: RunWallet,existing_scope=null,instance_id: String='') -> Dictionary:
 var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
 if result.ok:MOUNT062.install(content,scope,cells)
 return result
