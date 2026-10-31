"""Create an explicit diagnostic PCK from an exact exported public baseline.

Production resources stay untouched. Every replaced/removed entry and source
hash is recorded; input pack SHA must match the public baseline contract.
"""
from pathlib import Path
import argparse, hashlib, json, re, struct, sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from check_web_bundle import Pack
MEASURE={
 'game/presentation/world/underworld_plains/underworld_foreground.gd':['_refresh','_protection','_sync_residents','_render_receipt'],
 'game/presentation/world/underworld_plains/underworld_presentation.gd':['refresh'],
 'game/presentation/world/underworld_plains/underworld_parallax.gd':['_update'],
 'game/presentation/world/underworld_plains/underworld_home_world.gd':['update_focus'],
 'game/world/levels/providers/generated_demo_stage.gd':['_physics_process'],
 'game/world/levels/providers/plains_region_stage.gd':['_physics_process','capture_state','_update_context_signs'],
 'game/enemies/enemy_actor.gd':['_physics_process'],
 'game/progression/home/home_scene.gd':['_physics_process','_process'],
 'game/player/player_controller.gd':['_physics_process'],
 'game/application/demo_app.gd':['_process','_physics_process','_layout_region_hud','_sync_music'],
 'game/presentation/ui/demo_ui_01/game_hud.gd':['_process','_refresh','present_context'],
 'game/presentation/audio/game_audio.gd':['_process'],
 'game/presentation/audio/game_music.gd':['_process'],
 'game/presentation/audio/game_ambience.gd':['_process'],
 'game/presentation/audio/selected_ambience_runtime.gd':['_process'],
 'game/presentation/audio/home_ambience_audition.gd':['_process'],
}
HELPER='''
func _perf_record(method: String, elapsed: int) -> void:
	if not is_inside_tree(): return
	var root := get_tree().root
	var rows: Dictionary=root.get_meta("perf_costs",{})
	var key: String=method
	var row: Array=rows.get(key,[0,0,0])
	row[0]+=elapsed;row[1]+=1;row[2]=maxi(int(row[2]),elapsed)
	rows[key]=row
	root.set_meta("perf_costs",rows)
'''
AUDIO='''
var _perf_events: Array[Dictionary]=[]
func _play_original(id: StringName, stream_override: AudioStream = null) -> bool:
	if get_tree().root.get_meta("mobile_perf_audio_off",false):
		_perf_events.append({"cue":str(id),"accepted":false,"reason":"diagnostic_all_audio_off","busy_before":0,"real_usec":Time.get_ticks_usec(),"clock":_clock})
		return false
	var before:=_voices.filter(func(v):return v.playing).size()
	var reason:="unknown"
	var interval:=0.16 if id in [&"step", &"denied", &"armour"] else 0.055
	if _shutting_down:reason="shutting_down"
	elif not _streams.has(id):reason="missing_stream"
	elif volume<=0:reason="muted"
	elif get_tree().paused and id not in [&"click",&"confirm",&"denied"]:reason="paused"
	elif _clock-float(_last.get(id,-100.0))<interval:reason="interval"
	elif before==_voices.size():reason="pool_full"
	var accepted:=_perf_impl_play_original(id,stream_override)
	_perf_events.append({"cue":str(id),"accepted":accepted,"reason":"accepted" if accepted else reason,"busy_before":before,"real_usec":Time.get_ticks_usec(),"clock":_clock})
	if _perf_events.size()>4096:_perf_events.pop_front()
	return accepted
'''

def write_pack(pack,replacements,skip,target):
 # Retain original payload offsets/chunks and append a new exact directory.
 # Unreferenced original directory bytes are legal pack data. Header and only
 # the final partial chunk change; unchanged assets retain their exact bytes.
 import shutil
 shutil.copyfile(pack.path,target)
 entries=[(name,offset-pack.file_base,size,md5)for name,(offset,size,md5)in pack.entries.items()if name not in skip and name not in replacements]
 with target.open('r+b') as f:
  f.seek(0,2);f.write(bytes((-f.tell())%16))
  for name,data in replacements.items():
   pos=f.tell();f.write(data);f.write(bytes((-f.tell())%16));entries.append((name,pos-pack.file_base,len(data),hashlib.md5(data).digest()))
  directory=f.tell();f.write(struct.pack('<I',len(entries)))
  for name,pos,size,md5 in entries:
   b=name.encode();b+=bytes((-len(b))%4);f.write(struct.pack('<I',len(b)));f.write(b);f.write(struct.pack('<QQ',pos,size));f.write(md5);f.write(struct.pack('<I',0))
  f.seek(32);f.write(struct.pack('<Q',directory))
 # Parse and verify all replaced bytes; unchanged entries inherit checked base.
 result=Pack(target)
 for name,data in replacements.items():assert result.read(name)==data
 for name in set(pack.entries)-set(skip)-set(replacements):assert result.entries[name]==pack.entries[name]

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--bundle',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--expected-pack',required=True);args=parser.parse_args()
 info=json.loads((args.bundle/'build-info.json').read_text());original=args.bundle/info['pack'];digest=hashlib.sha256(original.read_bytes()).hexdigest();assert digest==args.expected_pack
 out=args.output;out.mkdir(exist_ok=False,parents=True);pack=Pack(original);replacement={};skip=set();sources={}
 for path,methods in MEASURE.items():
  source=(ROOT/path).read_text();sources[path]=hashlib.sha256(source.encode()).hexdigest()
  for name in methods:
   m=re.search(r'^func '+re.escape(name)+r'\(([^\n]*)\) -> void:',source,re.M)
   if not m:raise ValueError((path,name))
   arguments=m.group(1);params=[part.strip().split(':')[0].split('=')[0].strip() for part in arguments.split(',') if part.strip()]
   unique='_perf_impl_'+hashlib.sha256(path.encode()).hexdigest()[:8]+'_'+name
   wrapper=f'\nfunc {name}({arguments}) -> void:\n\tvar _perf_start:=Time.get_ticks_usec()\n'
   if path.endswith('demo_app.gd') and name=='_layout_region_hud':wrapper+='\tif get_tree().root.get_meta("mobile_perf_hud_off",false):return\n'
   wrapper+=f'\t{unique}({", ".join(params)})\n\t_perf_record("res://{path}:{name}",Time.get_ticks_usec()-_perf_start)\n'
   source=source[:m.start()]+source[m.start():].replace('func '+name+'(', 'func '+unique+'(',1);source+=wrapper
  if path.endswith('game_audio.gd'):
   source=source.replace('func _play_original(','func _perf_impl_play_original(',1)+AUDIO
   needle='\tget_tree().node_added.connect(_observe_button)';assert needle in source
   source=source.replace(needle,'\tvar perf:=load("res://mobile_perf_probe.gd").new() as Node\n\tperf.set_meta("app_ref",weakref(get_parent()))\n\tget_tree().root.add_child.call_deferred(perf)\n'+needle)
  if path.endswith('game_ambience.gd'):
   source=re.sub(r'voice.stream_paused = (is_paused|session_volume <= 0.0)',r'if not get_tree().root.get_meta("mobile_perf_audio_pause_guard",false) or voice.stream_paused != (\1): voice.stream_paused = \1',source)
  source+=HELPER;replacement[path]=source.encode();skip.add(path+'.remap')
 replacement['mobile_perf_probe.gd']=(ROOT/'tools/mobile_web_perf/probe.gd').read_bytes()
 write_pack(pack,replacement,skip,out/'diagnostic.pck')
 for p in args.bundle.glob('*.engine.*'):
  (out/p.name).symlink_to(p.resolve())
 for name in ['audio_probe.js','pcm_worklet.js','gpu_probe.js']:
  if (ROOT/'tools/mobile_web_perf'/name).is_file():(out/name).write_bytes((ROOT/'tools/mobile_web_perf'/name).read_bytes())
 engine='index.'+info['engine_id']+'.engine'
 (out/'index.html').write_text('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no"><style>body{margin:0;background:black;overflow:hidden;touch-action:none}canvas{display:block;image-rendering:pixelated}</style><script src="audio_probe.js"></script><script src="gpu_probe.js"></script></head><body><canvas id="canvas"></canvas><script src="'+engine+'.js"></script><script>const engine=new Engine({canvasResizePolicy:2,executable:'+json.dumps(engine)+',mainPack:"diagnostic.pck",focusCanvas:true,ensureCrossOriginIsolationHeaders:false});engine.startGame().then(()=>window.READY=true).catch(e=>console.error(e));</script></body></html>')
 receipt={'baseline_info':info,'baseline_pack_sha256':digest,'diagnostic_pack_sha256':hashlib.sha256((out/'diagnostic.pck').read_bytes()).hexdigest(),'replaced':list(replacement),'removed_remaps':sorted(skip),'source_sha256':sources,'measure':MEASURE,'scope':'diagnostic copy only; original production package unchanged; nested wrapper times inclusive'};(out/'build-receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps({'output':str(out),'diagnostic_pack_sha256':receipt['diagnostic_pack_sha256']}))
if __name__=='__main__':main()
