extends "res://tests/world/service_ui.gd"
## Terminal-HP Boss fixture isolates the real victory, pickup, NPC and save chain.
func stand(at:Vector2)->void:
 app.controller.router.clear("declared smith quest approach");app.player.reset_at(at)
 app.lifetime.invalidate_actor();app.controller.session_id+=1;(app.camera as WorldCamera).reset_view();await ticks(5)
func offer()->void:
 await stand(Vector2(904,2510));app._interact();await ticks(5);await click_named("继续")
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await app.review.begin("P-R11","","base");await ticks(5)
 var disk:=WorldSaveService.new();disk.configure("user://smith_upgrade_roundtrip.json",false,"smith_upgrade")
 disk.content_version=app.content.data.content_version;disk.payload_validator=app.state.valid
 for suffix:String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(disk.path+suffix)
 app.state.storage=disk
 check(app.state.commit(app._snapshot(),app.state.revision),"isolated quest uses actual disk service")
 check(app.room.get_node("Interaction_0").action_id=="pickup_skill_core_root","actual Boss reward host uses relocated skill core")
 check(not app.state.holds(app.content.action("pickup_skill_core_root").requires),"no skill core before actual Boss victory")
 await stand(app.room.battle_entry_anchor);await ticks(8)
 var hp:=app.room.encounter.health
 hp.apply_damage(ActorResourceRequest.new(&"smith_quest_boss_fixture",hp.epoch,hp.current+1,hp.get_instance_id()));await ticks(15)
 await stand(Vector2(2240,1134));app._interact();await ticks(5)
 check(app.state.has("found_skill_core_root") and app.state.value.inventory.get("skill_core",0)==1,"actual post-Boss pickup grants one material")
 check(not app.state.value.receipts.has("pickup_part_triple"),"P11 no longer gives triple part")
 check(not app.state.has("skill_tier_1"),"material pickup alone is not skill installation")
 await app.load_room("P-R10","");await settle();await ticks(5)
 await offer();await click_named("离开")
 check(not app.state.has("skill_tier_1") and app.state.value.inventory.skill_core==1,"cancel keeps uninstalled core")
 await offer()
 var gold:=int(app.services.ledger().gold)
 app.state.storage.blocked=true
 await click_named("交付素材")
 check(not app.state.has("skill_tier_1") and app.state.value.inventory.skill_core==1,"failed save leaves material and skill unchanged")
 app.state.storage.blocked=false
 await click_named("继续");await click_named("交付素材")
 check(app.state.has("skill_tier_1") and app.state.value.inventory.skill_core==0,"real touch hand-in installs skill and consumes one material")
 check(app.services.ledger().gold==gold,"first installation is free")
 check(app.controller.shoot_ability.weapon.branch==&"ice","accepted installation equips actual ice skill")
 var installed:=app.state.value.duplicate(true)
 check(not app.services.request("smith_install","install_skill_core_1","stale_upgrade",app.state.revision-1) and app.state.value==installed,"stale double tap cannot charge or install again")
 await click_named("离开")
 # Persist this isolated quest through the actual disk envelope, then normal Continue.
 check(app.state.commit(app._snapshot(),app.state.revision),"quest result saves to disk")
 app.return_title();await ticks(5)
 check(app.continue_world(),"normal Continue loads disk quest result");await settle();await ticks(5)
 check(app.state.has("skill_tier_1") and app.state.value.inventory.skill_core==0 and app.controller.shoot_ability.weapon.branch==&"ice","reload retains skill and consumed material")
 await app.load_room("P-R11","");await settle();await ticks(5)
 check(app.room.battle_finished and app.state.value.receipts.has("pickup_skill_core_root"),"revisit preserves Boss defeat and unique material receipt")
 check(app.content.action("pickup_part_triple").room_id=="T-R06","triple part moved to root twins reward")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("SMITH UPGRADE: ",failures," failures");quit(failures)
