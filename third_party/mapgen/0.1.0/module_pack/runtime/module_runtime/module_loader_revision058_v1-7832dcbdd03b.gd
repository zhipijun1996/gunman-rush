extends "module_loader_ideas_v2-14f1ba7244c3.gd"
## Third access receiver belongs to the same original native atomic pair.
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var result: Dictionary=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	if not result.ok:return result
	for spec: Dictionary in content.get("latches",[]):
		if not spec.has("additional_pair_access"):continue
		for latch in pairs.pairs:
			if str(latch.link_id)==str(spec.id):latch.add_access_bell(Vector2(spec.additional_pair_access[0],spec.additional_pair_access[1]),false,true)
	return result
