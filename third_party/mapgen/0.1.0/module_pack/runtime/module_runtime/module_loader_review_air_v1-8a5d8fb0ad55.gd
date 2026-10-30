extends "module_loader_v3-1d72f57d63dd.gd"
const REVIEW_AIR=preload("air_enemy_binding_v1-69824e7db4f1.gd")
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var original_enemies: Array=content.enemies
	content.enemies=REVIEW_AIR.ordinary(content).enemies
	var result:=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	content.enemies=original_enemies
	if result.ok:REVIEW_AIR.install(content,self,player,scope,cells)
	return result
