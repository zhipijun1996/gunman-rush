from pathlib import Path
import json,hashlib,re
R=Path('/workspace/gunman-rush-design');D=R/'build/forest_depth/level_capability/capture-preparation';D.mkdir(exist_ok=True)
s=(R/'tools/level_design_capture.gd').read_text();node=s.replace('extends SceneTree','extends Node',1).replace('func _initialize() -> void: run.call_deferred()\n','').replace('root.add_child(app)','get_tree().root.add_child(app)').replace('await physics_frame','await get_tree().physics_frame').replace('driver.tree = self','driver.tree = get_tree()').replace('quit(','finish_code(')
node=node.replace('var report: Dictionary = {}','var exit_code := 0\nvar report: Dictionary = {}')
node+='\nfunc finish_code(code: int) -> void:\n\texit_code=code\n'
# New helper must appear in its own producer hash evidence when admitted.
node=node.replace('["res://tools/level_design_capture.gd",','["res://tools/level_design_capture.gd", "res://tools/level_design_capture_case.gd",')
entry='''extends SceneTree
## Exit only after the original complete capture has returned and its Node freed.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var script: Script=load("res://tools/level_design_capture_case.gd")
	var capture: Node=script.new()
	root.add_child(capture)
	await capture.run()
	var code: int=capture.exit_code
	var capture_ref: WeakRef=weakref(capture)
	capture.free()
	capture=null
	script=null
	if capture_ref.get_ref()!=null:
		push_error("LEVEL DESIGN CAPTURE: owner retained after complete return")
		code=1
	quit(code)
'''
(D/'entry.gd.txt').write_text(entry);(D/'case.gd.txt').write_text(node)
a=re.findall(r'verify\((.*)',s);b=re.findall(r'verify\((.*)',node);assert a==b
(D/'mechanical-plan.json').write_text(json.dumps({'scope':'Offline only; not applied or executed','original_sha256':hashlib.sha256(s.encode()).hexdigest(),'helper_sha256':hashlib.sha256(node.encode()).hexdigest(),'verify_call_lines_exact':a==b,'original_verify_lines':a,'tree_frame_root_adaptations_only':True,'producer_hash_addition':'res://tools/level_design_capture_case.gd','original_args_and_driver_and_strategies_unchanged':True},indent=2)+'\n')
