extends Node
const GROUP=preload('revision059_group_motion_v1-a99b6384c5d8.gd')
const REWARD=preload('revision059_reward_pair_v1-71ff5858a7b7.gd')
const TURRET=preload('revision059_hit_turret_v1-94ccc147149c.gd')
const TURRET_LATCH=preload('revision059_turret_latch_v1-00806b019b04.gd')
var custom: Array=[]
var host
func setup(data: Dictionary,world: Node2D,player: PlayerController,scope,cells,rewards) -> void:
 host=world
 for spec: Dictionary in data.get('approved_hq_cells',[]):
  if spec.kind=='group_motion':
   var latch=GROUP.new();latch.link_id=str(spec.id);latch.formal_presentation=true;world.add_child(latch);latch.setup(player,scope.lifetime,Vector2(spec.bell[0],spec.bell[1]),Rect2(-4096,-4096,8,8))
   var targets: Array[ModuleMovingPlatform]=[]
   for id: String in spec.targets:
    for p: ModuleMovingPlatform in scope.module.moving_platforms:
     if str(p.definition.platform_id)==id:targets.append(p)
   latch.bind_group(targets,scope)
   for at: Array in spec.access:latch.add_access_bell(Vector2(at[0],at[1]),false,false)
   latch.opened.connect(cells._bell_open.bind(latch,str(spec.id)));cells.latches.append(latch);custom.append(latch)
  if spec.kind=='reward_pair':
   var pair=REWARD.new();pair.link_id=spec.id;world.add_child(pair);var a: Array=spec.gate;var b: Array=spec.paired_gate
   pair.setup_pair(player,scope.lifetime,Vector2(-4096,-4096),Rect2(a[0],a[1],a[2],a[3]),Rect2(b[0],b[1],b[2],b[3]),spec.initial_open,scope);pair.bell_body.collision_layer=0
   rewards.services[str(spec.reward_id)].committed.connect(pair.accept_reward);custom.append(pair)
  if spec.kind=='hit_turret':
   var original: Dictionary={}
   for l: Dictionary in data.latches:
    if str(l.id)==str(spec.latch_id):original=l
   var latch=TURRET_LATCH.new();latch.link_id=str(spec.latch_id);latch.formal_presentation=true;latch.open_seconds=original.open_seconds;world.add_child(latch);var r: Array=original.gate;latch.setup(player,scope.lifetime,Vector2(original.bell[0],original.bell[1]),Rect2(r[0],r[1],r[2],r[3]));latch.add_access_bell(Vector2(original.return_access[0],original.return_access[1]),false,false);latch.opened.connect(cells._bell_open.bind(latch,str(latch.link_id)));cells.latches.append(latch)
   var turret=TURRET.new();world.add_child(turret);turret.setup(spec,player,scope,latch);custom.append(turret)
func snapshot() -> Array:
 var result: Array=[]
 for cell in custom:
  if cell.has_method('snapshot_pair'):result.append(cell.snapshot_pair())
  elif 'events'in cell:result.append({'events':cell.events.duplicate(true)})
 return result
static func ordinary(data: Dictionary) -> Dictionary:
 var v:=data.duplicate(true)
 for s: Dictionary in data.get('approved_hq_cells',[]):
  if s.kind=='hit_turret':v.latches=v.latches.filter(func(l: Dictionary):return str(l.id)!=str(s.latch_id))
 return v
