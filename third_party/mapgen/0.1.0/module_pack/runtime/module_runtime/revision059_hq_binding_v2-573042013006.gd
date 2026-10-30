extends "revision059_hq_binding_v1-18ccd28b08c7.gd"
## Explicit pre-bind persisted state, suppressing new reward service creation.
func setup(data: Dictionary,world: Node2D,player: PlayerController,scope,cells,rewards) -> void:
 var state: Dictionary=data.get('approved_hq_saved_state',{})
 if state.is_empty():super.setup(data,world,player,scope,cells,rewards);return
 var ordinary:=data.duplicate(true);ordinary.approved_hq_cells=ordinary.approved_hq_cells.filter(func(s: Dictionary):return s.kind!='reward_pair');super.setup(ordinary,world,player,scope,cells,rewards)
 for spec: Dictionary in data.get('approved_hq_cells',[]):
  if spec.kind!='reward_pair':continue
  var pair=REWARD.new();pair.link_id=spec.id;world.add_child(pair);var a: Array=spec.gate;var b: Array=spec.paired_gate;pair.setup_pair(player,scope.lifetime,Vector2(-4096,-4096),Rect2(a[0],a[1],a[2],a[3]),Rect2(b[0],b[1],b[2],b[3]),spec.initial_open,scope);pair.bell_body.collision_layer=0
  if not pair.restore_state(state):world.setup_error='invalid_reward_pair_restore';return
  custom.append(pair)
  for reward: Dictionary in data.get('reward_sites',[]):
   var sprite:=Sprite2D.new();world.add_child(sprite);UnderworldObjects.place_chest(sprite,Vector2(reward.position[0],reward.position[1]+18),true)
