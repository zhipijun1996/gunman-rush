extends "module_loader_v3-1d72f57d63dd.gd"
const GEARS=preload("retractable_gears_v1-3c1f66141703.gd")
var gear_groups: Array=[]

func bind_player(player: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, wallet: RunWallet, existing_scope=null, instance_id: String="") -> Dictionary:
	var original_latches: Array=content.latches
	content.latches=content.latches.filter(func(l):return l.get("kind","")!="retractable_gears/v1")
	var result:=super.bind_player(player,policy,lifetime,wallet,existing_scope,instance_id)
	content.latches=original_latches
	if result.ok:
		for spec: Dictionary in content.get("retractable_groups",[]):
			var group=GEARS.new();group.configure(spec,self,player,scope)
			group.opened.connect(cells._bell_open.bind(group,str(spec.id)))
			cells.latches.append(group);gear_groups.append(group)
	return result

func snapshot() -> Dictionary:
	var result:=super.snapshot()
	if result.get("bound",false):result.workshop.retractable_groups=gear_groups.map(func(g):return g.snapshot_gears())
	return result
