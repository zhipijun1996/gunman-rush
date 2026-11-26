extends SceneTree
const Edit := preload("res://addons/mechanism_library/room_edit.gd")
const Info := preload("res://addons/mechanism_library/catalog_info.gd")
const ROOM := "res://tests/perception_demo.json"
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)

func _initialize() -> void:
	var temp := "user://mechanism-editor-test-"+str(OS.get_process_id())+".json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ROOM),ProjectSettings.globalize_path(temp))
	var initial := Edit.snapshot(temp)
	var choices := Info.palette("thorn_forest","G27")
	check(choices.size()==1 and choices[0].id=="environment.local_light","编号检索")
	check(Info.palette("thorn_forest","引路").size() >= 1,"中文检索")
	check(Info.palette("invalid_world_region","").is_empty(),"未知区域无可放置项")
	var bad_labels := []
	for item: Dictionary in Info.palette("thorn_forest",""):
		var d: Dictionary = WorldElementCatalog.catalog().definitions[item.id]
		for key: String in Info.fields(d):
			if Info.fields(d)[key].label == key: bad_labels.append(item.id+":"+key)
	check(bad_labels.is_empty(),"字段缺少中文名称 "+str(bad_labels))
	var fields := Info.fields(WorldElementCatalog.catalog().definitions["environment.local_light"])
	check(fields.move_speed.unit != "" and fields.move_speed.hint.contains("灯虫"),"单位或模式约束缺失 "+str(fields.move_speed))
	check(not fields.has("element_id"),"派生身份不能被改写")
	var op := {"kind":"add","id":"new_reeds","definition":"zone.sight_occluder","at":[100,50],"fields":{"bounds":[4,8,64,32]}}
	var preview := Edit.execute(temp,initial.hash,op,false)
	check(WorldRoomValidation.rectangle(preview.get("changed",{}).get("new_reeds",{}).get("properties",{}).get("bounds")) and FixedWorldProvider.rect(preview.changed.new_reeds.properties.bounds)==Rect2(104,58,64,32),"基本件坐标仅转换一次 "+str(preview))
	check(Edit.snapshot(temp).hash == initial.hash,"预览写入了房间")
	var saved := Edit.execute(temp,initial.hash,op,true)
	check(saved.get("saved",false),"保存基本件 "+str(saved))
	var actual := Edit.snapshot(temp)
	check(actual.doc.entities.has("new_reeds") and actual.doc.entities.floor == initial.doc.entities.floor,"保留原有房间内容")
	check(Edit.execute(temp,initial.hash,op,true).get("error")=="room_changed_on_disk","过期来源哈希未拦截")
	check(Edit.execute(temp,actual.hash,op,true).has("error"),"ID 冲突未拦截")
	var invalid := {"kind":"edit","id":"new_reeds","fields":{"minimum_overlap":-1}}
	check(Edit.execute(temp,actual.hash,invalid,false).has("error"),"没有检查字段合同")
	var assembly := {"kind":"add","id":"bell_pair","definition":"assembly.bell_gate","at":[100,120],"fields":{"mode":"timed","bell.duration":3.5}}
	var placed := Edit.execute(temp,actual.hash,assembly,true)
	check(placed.get("saved",false),"预组没有通过正式装配 "+str(placed))
	if placed.get("saved",false):
		var source: Dictionary = Edit.snapshot(temp).doc
		check(source.entities["bell_pair/bell"].properties.duration == 3.5,"预组创建覆写丢失")
		var edit_member := Edit.apply(source,{"kind":"edit","id":"bell_pair/bell","fields":{"duration":1.75}})
		check(edit_member.get("entities",{}).get("bell_pair/bell",{}).get("properties",{}).get("duration")==1.75,"已放置成员不可单独编辑 "+str(edit_member.get("error")))
		if not edit_member.has("error"):
			var move := Edit.apply(edit_member,{"kind":"move","group":"bell_pair","at":[30,-20]})
			check(not move.has("error") and FixedWorldProvider.point(move.entities["bell_pair/bell"].properties.position) == FixedWorldProvider.point(edit_member.entities["bell_pair/bell"].properties.position)+Vector2(30,-20),"移动改变了局部布局 "+str(move.get("error")))
			var copy := Edit.apply(edit_member,{"kind":"copy","group":"bell_pair","id":"clone","at":[50,0]})
			check(not copy.has("error") and copy.entities["clone/bell"].properties.links[0].target=="clone/gate" and copy.entities["clone/bell"].properties.duration==1.75,"复制未保留逐件编辑或重接内部连线")
			var detach := Edit.apply(edit_member,{"kind":"detach","group":"bell_pair"})
			check(not detach.has("error") and not detach.entities["bell_pair/bell"].has("assembly_id"),"解除分组")
	var wave := Edit.apply(actual.doc,{"kind":"add","definition":"assembly.windchime_bell_walkway","id":"wave","at":[160,200]})
	check(not wave.has("error"),"展开波次预组 "+str(wave.get("error")))
	if not wave.has("error"):
		var stats := Info.derived(wave.entities["wave/drive"])
		check(is_equal_approx(stats["名义总时长（s）"],3.15) and is_equal_approx(stats["相邻稳定重叠（s）"],0.6),"展开后的只读派生时序 "+str(stats))
	var latest := Edit.snapshot(temp)
	var file := FileAccess.open(temp,FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string(" \n")
	file.close()
	var changed_disk := Edit.snapshot(temp)
	check(latest.hash != changed_disk.hash and Edit.execute(temp,latest.hash,assembly,true).get("error")=="room_changed_on_disk" and Edit.snapshot(temp).hash==changed_disk.hash,"外部写入保护")
	DirAccess.remove_absolute(temp)
	print("MECHANISM EDITOR failures=",failures," checks=",checks)
	quit(0 if failures == 0 else 1)
