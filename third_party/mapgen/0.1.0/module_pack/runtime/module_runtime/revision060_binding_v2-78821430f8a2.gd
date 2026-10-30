extends "revision059_hq_binding_v2-573042013006.gd"
const SUPPORT_START=preload('revision060_support_start_v1-5f36f2dd420c.gd')
const THORN_LATCH=preload('revision060_thorn_latch_v2-05ca725eb5cd.gd')
func setup(data: Dictionary,world: Node2D,player: PlayerController,scope,cells,rewards) -> void:
 var ordinary:=data.duplicate(true);ordinary.approved_hq_cells=ordinary.get('approved_hq_cells',[]).filter(func(s: Dictionary):return s.kind not in ['native_one_way_carriers','support_start_motion','projectile_barrier','retract_thorns'] and not(s.kind=='hit_turret'and s.get('latch_id','')=='target-bell'));super.setup(ordinary,world,player,scope,cells,rewards)
 for spec: Dictionary in data.get('approved_hq_cells',[]):
  if spec.kind=='native_one_way_carriers':
   for p: ModuleMovingPlatform in scope.module.moving_platforms:
    if not str(p.definition.platform_id)in spec.ids:continue
    for child: Node in p.get_children():
     if child is CollisionShape2D:child.one_way_collision=true
    p.add_to_group('one_way_platform')
  if spec.kind=='projectile_barrier':
   for p: ModuleMovingPlatform in scope.module.moving_platforms:
    if str(p.definition.platform_id)==str(spec.id):p.collision_layer=8
  if spec.kind=='support_start_motion':
   for p: ModuleMovingPlatform in scope.module.moving_platforms:
    if str(p.definition.platform_id)==str(spec.id):var start=SUPPORT_START.new();world.add_child(start);start.setup(p,player,scope);custom.append(start)
  if spec.kind=='retract_thorns':
   var latch=THORN_LATCH.new();world.add_child(latch);latch.setup_thorns(player,scope,Vector2(spec.bell[0],spec.bell[1]),Vector2(spec.access[0],spec.access[1]),spec.hazards);latch.opened.connect(cells._bell_open.bind(latch,str(latch.link_id)));cells.latches.append(latch);custom.append(latch)
 for spec: Dictionary in data.get('approved_hq_cells',[]):
  if spec.kind=='hit_turret' and spec.get('latch_id','')=='target-bell':
   var latch
   for l: ShotLatch in cells.latches:
    if str(l.link_id)=='target-bell':latch=l
   # The exit-thorn receiver also accepts explicit child mechanism identities.
   var turret=TURRET.new();world.add_child(turret);turret.setup(spec,player,scope,latch);custom.append(turret)
