extends "res://tests/item_v5_ui_input_runner.gd"
func capture_menu_views(menu: DemoMenu, destination: String) -> void:
 if DisplayServer.get_name() == "headless":
  check(false,"golden menus require actual GL")
  return
 var directory := ProjectSettings.globalize_path(destination)
 check(DirAccess.make_dir_recursive_absolute(directory) == OK,"golden output writable")
 var ids: Array[StringName] = [&"B01",&"B03",&"B11",&"P24",&"P14",&"G14",&"G16",&"N01"]
 var items: Array[Dictionary] = []
 var worn: Array[StringName] = [&"P24",&"P14"]
 for id: StringName in ids:
  var item := ItemCatalogV5.get_item(id)
  check(item != null and ItemArtLibrary.has_icon(item.icon_key),"real icon declared for "+String(id))
  items.append({"instance_id":StringName("golden/"+String(id)),"definition":item,"level":item.max_level,"max_level":item.max_level,"equipped":id in worn,"active_capable":&"active" in item.tags,"active_selected":id == &"P24"})
 var added := 0
 for item: ItemDefinition in ItemCatalogV5.all_items():
  if item.stable_id in ids or added >= 12: continue
  items.append({"instance_id":StringName("backlog/"+String(item.stable_id)),"definition":item,"level":1,"max_level":item.max_level,"equipped":false,"active_capable":&"active" in item.tags})
  added += 1
 var snapshot := {"capacity":8,"used":6,"remaining":2,"revision":71,"session":19,"coins":90,"summary":"独立图标样板8件 · 背包为显示初始化，其他美术待制作","items":items,"upgrade":{"available":false,"price":0,"capacity":8,"reason":"美术显示样板"}}
 var evidence: Array = []
 var old_size := root.size
 var old_scale := root.content_scale_size
 for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
  root.size = size
  root.content_scale_size = size
  menu.show_build("")
  menu.set_equipment_view(snapshot)
  await process_frame
  menu.call("_select_equipment",&"golden/G16")
  for i: int in 8: await process_frame
  await capture_menu_png(menu,directory,"golden-menu-%sx%s-top" % [size.x,size.y],size,evidence)
  var scroll := menu.find_child("BackpackScroll",true,false) as ScrollContainer
  check(scroll != null and scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page,"realgoldenmenu has scrolling backlog")
  if scroll != null: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
  menu.call("_select_equipment",&"golden/N01")
  for i: int in 4: await process_frame
  await capture_menu_png(menu,directory,"golden-menu-%sx%s-scrolled" % [size.x,size.y],size,evidence)
 menu.close_panel()
 root.size = old_size
 root.content_scale_size = old_scale
 var file := FileAccess.open(directory.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"ActualDemoMenu/ItemPresentation8goldenicons+12existingbacklog snapshotfixture. RealGL1280and960; sourceunmodified highresROI recipe; notnaturalownership/effectcommit/physicalAndroid orfull72art.","golden_ids":ids,"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"rows":evidence},"  "))
 file.close()
 ItemArtLibrary.clear_cache()
