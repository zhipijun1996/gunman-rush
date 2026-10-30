extends "module_loader_v3-1d72f57d63dd.gd"
const WAVE=preload("review029_ambush_v2-20b11f356d1a.gd")
var wave
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var full:=content
	content=content.duplicate(true);content.enemies=[]
	var result:=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	content=full
	if result.ok:
		wave=WAVE.new();add_child(wave);wave.setup(content,self,player,scope,cells,self)
	return result
func snapshot() -> Dictionary:
	var value:=super.snapshot()
	if is_instance_valid(wave):value.review029_wave=wave.snapshot()
	return value
