from pathlib import Path
p=Path('tests/plains_redesign_spatial_runner.gd');s=p.read_text();s=s.replace('var broken:=false','var broken:=false\nvar platform_only:=false\nvar receiver_fault: Dictionary={}');s=s.replace('if arg=="--delete-receiver": broken=true','if arg=="--delete-receiver": broken=true\n\t\tif arg=="--delete-receiver-platform-only": broken=true;platform_only=true');s=s.replace('well.get_node("Platform1").free() # Remove the actual right bank collider, not a reported coordinate.','receiver_fault=delete_receiver(trace.stage,well,not platform_only)');s=s.replace('"deleted_receiver":broken,','"deleted_receiver":broken,"platform_only":platform_only,"receiver_fault":receiver_fault,')
insert='''
# Fault injection only: the actual receiving shore comprises its slab AND the
# collision-bearing earth directly attached beneath the slab. No production
# lifecycle behavior, other bank, lower room or unrelated support is changed.
func rect_array(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func support_inventory(supports: PlainsGroundSupports) -> Array:
	var rows: Array=[]
	if not is_instance_valid(supports):return rows
	for body: Node in supports.get_children():
		if not body is StaticBody2D:continue
		for child: Node in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var shape: RectangleShape2D=child.shape
				rows.append({"path":str(body.get_path()),"instance_id":body.get_instance_id(),"rect":rect_array(Rect2(body.position+child.position-shape.size*.5,shape.size)),"collision_layer":body.collision_layer})
	return rows
func delete_receiver(assembler: PlainsRegionAssembler,well: PlatformingModule,complete: bool) -> Dictionary:
	var slab: Rect2=well.definition.platforms[1]
	var receiver:=Rect2(well.position+slab.position,slab.size)
	var supports: PlainsGroundSupports=assembler.ground_supports
	var before:=support_inventory(supports)
	var removed: Array=[]
	var kept: Array[Rect2]=[]
	well.get_node("Platform1").free()
	if complete and is_instance_valid(supports):
		for column: Rect2 in supports.columns:
			var left:=maxf(column.position.x,receiver.position.x)
			var right:=minf(column.end.x,receiver.end.x)
			if not is_equal_approx(column.position.y,receiver.end.y) or right<=left:
				kept.append(column);continue
			removed.append(rect_array(Rect2(Vector2(left,column.position.y),Vector2(right-left,column.size.y))))
			if left>column.position.x:kept.append(Rect2(column.position,Vector2(left-column.position.x,column.size.y)))
			if right<column.end.x:kept.append(Rect2(Vector2(right,column.position.y),Vector2(column.end.x-right,column.size.y)))
		# Preserve unrelated bodies and their IDs; replace only intersecting body
		# pieces by exact left/right remainders, rather than clearing all earth.
		for body: Node in supports.get_children():
			if not body is StaticBody2D:continue
			var shape_node:=body.get_child(0) as CollisionShape2D
			var rectangle:=shape_node.shape as RectangleShape2D
			var bounds:=Rect2(body.position+shape_node.position-rectangle.size*.5,rectangle.size)
			if not is_equal_approx(bounds.position.y,receiver.end.y) or bounds.end.x<=receiver.position.x or bounds.position.x>=receiver.end.x:continue
			var pieces: Array[Rect2]=[]
			if bounds.position.x<receiver.position.x:pieces.append(Rect2(bounds.position,Vector2(receiver.position.x-bounds.position.x,bounds.size.y)))
			if bounds.end.x>receiver.end.x:pieces.append(Rect2(Vector2(receiver.end.x,bounds.position.y),Vector2(bounds.end.x-receiver.end.x,bounds.size.y)))
			body.free()
			for piece: Rect2 in pieces:
				var replacement:=StaticBody2D.new();replacement.position=piece.get_center();replacement.collision_layer=1
				var collision:=CollisionShape2D.new();var actual:=RectangleShape2D.new();actual.size=piece.size;collision.shape=actual
				replacement.add_child(collision);supports.add_child(replacement)
		supports.columns=kept;supports.queue_redraw()
	var after:=support_inventory(supports)
	check(not before.is_empty(),"receiver fault observes actual collision-bearing earth before deletion")
	check(not complete or not removed.is_empty(),"complete receiver deletion removes attached earth only")
	return {"complete":complete,"receiver":rect_array(receiver),"slab_path":str(well.get_path())+"/Platform1","support_before":before,"support_after":after,"removed_fragments":removed,"scope":"actual slab plus exact immediately attached support footprint only; unrelated collider IDs retained"}

'''
s=s.replace('func finish() -> void:',insert+'func finish() -> void:');p.write_text(s)
p=Path('scripts/generation/stage_camera_rig.gd');s=p.read_text();s=s.replace('safe.y = maxf(safe.y,region_focus.y+18.0-half_height+40.0)','var landing_min := region_focus.y+18.0-half_height+40.0\n\t\t# Elective extra upward recoil can exceed one-screen bank coverage.\n\t\t# The full actor safety envelope remains authoritative in that case.\n\t\tsafe.y = minf(maxf(safe.y,landing_min),actor_position.y+margin.y)');p.write_text(s)
p=Path('scripts/art/plains_region_composition.gd');s=p.read_text();s=s.replace('origin+Vector2(90,-15), 130','origin+Vector2(55,-10), 130');p.write_text(s)
