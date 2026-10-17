extends SceneTree
## Native planner contracts. Formal map/route/art admission requires separate capture.
var failures: Array[String]=[]
func _initialize() -> void:
	var adapter := P1RandomPlainsSample.new()
	var step := PackedVector4Array([Vector4(0,100,200,100),Vector4(200,100,200,60),Vector4(200,60,400,60)])
	var top: Array=adapter.call("_top",step)
	_check(top==[[0.0,100.0],[200.0,100.0],[200.0,60.0],[400.0,60.0]],"actual step preserved without invented slope")
	var page: Array=adapter.call("_slice_top",top,0.0,400.0,300.0)
	_check(page[-1]==[260.0,60.0],"finite source budget includes vertical step arc")
	var arc := 0.0
	for i: int in page.size()-1:arc+=Vector2(page[i][0],page[i][1]).distance_to(Vector2(page[i+1][0],page[i+1][1]))
	_check(is_equal_approx(arc,300.0),"no whole-bank compression or source overrun")
	var hole_top := PackedVector4Array([Vector4(0,0,400,0),Vector4(100,40,200,40)])
	_check((adapter.call("_top",hole_top) as Array).is_empty(),"overlapping top runs refuse holes/overhang ambiguity")
	var gap_top := PackedVector4Array([Vector4(0,0,100,0),Vector4(120,0,300,0)])
	_check((adapter.call("_top",gap_top) as Array).is_empty(),"disconnected top never bridges real gap")
	var following: Array=adapter.call("_slice_top",top,220.0,400.0,120.0)
	_check(following[0]==[220.0,60.0] and following[-1]==[340.0,60.0],"overlap page retains actual footline")
	var l_parts: Array[Rect2]=[Rect2(0,0,40,200),Rect2(40,160,160,40)]
	_check(not adapter.call("_rect_in_union",Rect2(100,40,20,20),l_parts),"L union AABB must not hide disconnected slab")
	_check(adapter.call("_rect_in_union",Rect2(0,160,200,40),l_parts),"canonical quad spanning member boundary belongs to actual union")
	_check(not adapter.call("_rect_in_union",Rect2(0,0,200,200),l_parts),"partial union coverage never hides whole baseline quad")
	adapter.free()
	for failure: String in failures:push_error(failure)
	print("P1 RANDOM PLANNER TESTS: ","PASS" if failures.is_empty() else "FAIL", " assertions=9 scope=planner_not_native_route_or_art")
	quit(0 if failures.is_empty() else 1)
func _check(value: bool,label: String) -> void:
	if not value:failures.append(label)
