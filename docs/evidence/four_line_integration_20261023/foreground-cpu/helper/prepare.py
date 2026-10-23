from pathlib import Path
import hashlib,json,re,subprocess
r=Path('/workspace/integration-four');o=Path(__file__).parent
base='a38040c294aa541ed707bc50c55cf3769ecd7852';p='scripts/underworld_plains/underworld_foreground.gd'
sources={'old':subprocess.check_output(['git','show',base+':'+p],cwd=r,text=True),'new':(r/p).read_text()}
def function(s,name):
 start=s.index('func '+name+'(');end=s.find('\nfunc ',start+1)
 return s[start:end if end>=0 else len(s)].rstrip()+'\n'
prefix='''extends CanvasLayer
const MAX_PROTECTION := 64
const WIND_MARGIN := 3.0
var _protect: Array[Rect2] = []
var _dynamic_protect: Array[Rect2] = []
var _static_protect: Array[Rect2] = []
var _source_counts: Dictionary = {}
var _overflow := false
var _protection_viewport := Rect2()
var _protection_canvas := Transform2D.IDENTITY
func set_masks(masks: Array) -> void:
	_static_protect.clear()
	_static_protect.append_array(masks)
func state() -> Dictionary:
	return {"protect":_protect.duplicate(),"dynamic":_dynamic_protect.duplicate(),"static":_static_protect.duplicate(),"counts":_source_counts.duplicate(),"overflow":_overflow}
'''
manifest={'base_commit':base,'root':'/workspace/integration-four','scope':'Actual extracted helper bodies, minimal CanvasLayer context; no gameplay or runtime foreground refresh/admission claim','source_sha256':{},'helper_sha256':{}}
for label,src in sources.items():
 pre=function(src,'_protection').split('\tfor rect: Rect2 in _fixed_world:')[0].replace('func _protection() -> void:','func begin_pass() -> void:')
 assert pre.endswith('_overflow=false\n')
 body=prefix+'\n'+pre+'\n'+''.join(function(src,n)+'\n' for n in ['_add','_world_rect','_exposed_regions'])
 path=o/(label+'_helper.gd');path.write_text(body)
 manifest['source_sha256'][label]=hashlib.sha256(src.encode()).hexdigest();manifest['helper_sha256'][label]=hashlib.sha256(body.encode()).hexdigest()
(o/'extraction.json').write_text(json.dumps(manifest,indent=2)+'\n')
