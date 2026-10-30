extends RefCounted
## Apply the approved rigid receiver offset after native carrier parenting.
## This is fixture binding only; no actor, clock, trajectory or resource writes.
static func install(data: Dictionary,scope,cells) -> void:
 for spec: Dictionary in data.get('approved_hq_cells',[]):
  if spec.kind!='rigid_mounted_bell':continue
  for latch: ShotLatch in cells.latches:
   if str(latch.link_id)!=str(spec.id):continue
   for p: ModuleMovingPlatform in scope.module.moving_platforms:
    if str(p.definition.platform_id)!=str(spec.mount):continue
    if latch.get_parent()!=p:latch.reparent(p,true)
    latch.position=Vector2(spec.offset[0],spec.offset[1])-latch.bell_body.position
