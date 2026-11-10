extends "res://tests/world/service_ui.gd"
## Real visiting NPC and touch dialogue. Reward installation has its own world transaction.
func visible_copy()->String:
 var result:=""
 for node:Node in app.ui.root.find_children("*","Label",true,false):
  if node.is_visible_in_tree():result+=node.text+"\n"
 return result
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R10","","base"),"P10 formal review starts")
 await ticks(6)
 app.player.reset_at(Vector2(904,2510));app.controller.router.clear("smith approach fixture")
 await ticks(6)
 check(app.player.is_on_floor(),"smith dialogue stands on actual lower bank")
 check(app.context_target().get("id","")=="NPC_G_SMITH","lower bank resolves visiting weaponsmith")
 app._interact();await ticks(6)
 check(app.paused and app.ui.page=="dialogue" and visible_copy().contains("相信手里的家伙"),"actual smith interaction opens first line")
 await click_named("继续")
 check(visible_copy().contains("补回一发弹药") and not visible_copy().contains("恢复开枪冷却"),"teaching describes actual airborne hit rule")
 await click_named("继续")
 check(visible_copy().contains("上头藏着些好东西"),"teaching points toward authored upper reward")
 await click_named("离开")
 check(not app.paused and not app.state.has("skill_tier_1"),"leaving teaching resumes play without granting a skill")
 # Declared unlocked-state fixture tests repeat dialogue and device hints only.
 var candidate:=app.state.value.duplicate(true)
 candidate.flags.append("skill_tier_1")
 check(app.state.commit(candidate,app.state.revision),"explicit unlocked dialogue fixture")
 app._apply_capabilities()
 for device:StringName in [&"keyboard_mouse",&"gamepad",&"touch"]:
  app.service_view.input_device=func()->StringName:return device
  app._interact();await ticks(3)
  check(visible_copy().contains("冰弹"),"unlocked dialogue names ice skill")
  await click_named("继续")
  check(visible_copy().contains({&"keyboard_mouse":"Q 键",&"gamepad":"Y 键",&"touch":"屏幕上的技能按钮"}[device]),"actual device instruction "+str(device))
  await click_named("继续")
  check(visible_copy().contains("齿轮工城"),"future upgrade destination")
  await click_named("离开")
 check(app.controller.shoot_ability.weapon==preload("res://resources/weapons/pulse_ice.tres"),"capability adapter equips actual ice definition")
 await app.review.begin("P-R12","","base");await ticks(6)
 check(app.room.enemies["P-R12:r8:west_patrol"].health.capacity==9,"P12 guard follows explicit 9HP decision")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("SMITH DIALOGUE: ",failures," failures");quit(failures)
