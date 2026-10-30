extends "module_loader_review_air_v1-8a5d8fb0ad55.gd"
const REFRESH=preload("refresh_cells_v1-25befff692f8.gd")
var refresh_consumers: Array=[]
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var original: Array=content.latches
	content.latches=REFRESH.ordinary(content).latches
	var result:=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	content.latches=original
	if result.ok:refresh_consumers=REFRESH.install(content,self,player,scope,cells)
	return result
func snapshot() -> Dictionary:
	var result:=super.snapshot()
	result.refresh_consumers=refresh_consumers.map(func(c):return c.snapshot())
	return result
