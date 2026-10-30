extends RefCounted
## Loads authored base scenes. map-gen materializes mirrored content and gear closures.
## The host owns the existing PlayerController, wallet, lifetime and damage policy.
var catalog: Dictionary
var package_root: String
var instances: Dictionary={}
var instance_policies: Dictionary={}

func open(root_path: String) -> Dictionary:
 package_root=root_path.trim_suffix("/")
 var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(package_root.path_join("catalog.json")))
 if not parsed is Dictionary or parsed.get("schema")!="map-edit/delivery-catalog/v1":return {"ok":false,"reason":"invalid_delivery_catalog"}
 catalog=parsed
 return {"ok":true,"modules":catalog.modules.size()}

func instantiate_module(module_id: String, instance_id: String, origin_blocks: Vector2i, parent: Node2D, player: PlayerController, services: Dictionary, configuration: String="base") -> Dictionary:
 if instance_id.is_empty() or instances.has(instance_id):return {"ok":false,"reason":"empty_or_duplicate_instance_id"}
 var entry: Dictionary={}
 for candidate: Dictionary in catalog.get("modules",[]):
  if candidate.id==module_id:entry=candidate;break
 if entry.is_empty():return {"ok":false,"reason":"module_not_in_package"}
 if not services.has_all(["policy","lifetime","wallet"]):return {"ok":false,"reason":"explicit_host_services_required"}
 if not parent.global_transform.x.is_equal_approx(Vector2.RIGHT) or not parent.global_transform.y.is_equal_approx(Vector2.DOWN):return {"ok":false,"reason":"uncertified_parent_transform"}
 if configuration!="base":return {"ok":false,"reason":"unknown_interface_layout"}
 var path:=package_root.path_join(entry.scene)
 var packed: PackedScene=load(path)
 if packed==null:return {"ok":false,"reason":"scene_load_failed"}
 var instance: Node2D=packed.instantiate()
 var offset: Array=entry.sceneOriginOffsetPixels
 # Origin is the owned rectangle's top-left, not the old editor canvas origin.
 var world_origin:=Vector2(origin_blocks)*float(entry.blockSize)
 instance.position=parent.to_local(world_origin+Vector2(offset[0],offset[1]))
 parent.add_child(instance)
 var args: Array=[player,services.policy,services.lifetime,services.wallet,null,instance_id]
 for method: Dictionary in instance.get_method_list():
  if method.name=="bind_player" and method.args.size()>6:args.append(services.get("meta"));args.append(services.get("region_state"));break
 var bound: Dictionary=instance.callv("bind_player",args)
 if not bound.get("ok",false):instance.free();return bound
 instances[instance_id]=instance;instance_policies[instance_id]=services.policy
 instance.tree_exiting.connect(_release_identity.bind(instance_id))
 return {"ok":true,"instance":instance,"instance_id":instance_id,"world_origin":world_origin,"player_spawned":false,"resources_reset":false}

func unload(instance_id: String) -> void:
 var instance: Variant=instances.get(instance_id)
 if is_instance_valid(instance):instance.queue_free()
 instances.erase(instance_id)

func _release_identity(instance_id: String) -> void:
 var policy: Variant=instance_policies.get(instance_id)
 var prefix:="module/"+instance_id.uri_encode()+"/"
 if is_instance_valid(policy):
  for key: Variant in policy._targets.keys():
   if str(key).begins_with(prefix):policy._targets.erase(key)
  policy._queue=policy._queue.filter(func(request: DamageRequest) -> bool:return not str(request.target_id).begins_with(prefix) and not str(request.source_id).begins_with(prefix))
  for key: Variant in policy._seen.keys():
   if str(key).begins_with(prefix) or str(key).contains("/"+prefix):policy._seen.erase(key)
 instance_policies.erase(instance_id);instances.erase(instance_id)
