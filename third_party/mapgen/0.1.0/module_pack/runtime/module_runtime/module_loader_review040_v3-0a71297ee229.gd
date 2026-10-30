extends "module_loader_review040_v2-8cec818b6d39.gd"
const RELEASE_OVERLAY=preload("review040_release_overlay_v1-933fa626d096.gd")
func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var result:=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	if result.ok:
		var overlay=RELEASE_OVERLAY.new();overlay.configure(committed_release,content.review040_release.rect);module.add_child(overlay)
	return result
