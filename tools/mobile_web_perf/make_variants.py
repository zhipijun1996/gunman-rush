"""Official single/threaded template pairing and explicit diagnostic controls.

Never rewrites the source official engine. No routing behavior changes until
MOBILE_PERF_MASTER_ROUTING(true) is explicitly invoked by the diagnostic UI.
"""
from pathlib import Path
from zipfile import ZipFile
import argparse,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[2]
HOOK='''if(!globalThis.MOBILE_PERF_MASTER_ROUTING){let saved=false;let prior=null;globalThis.MOBILE_PERF_MASTER_ROUTING=function(fixed){const master=GodotAudio.Bus.getBusOrNull(0);if(!master)return;if(fixed){if(!saved){prior=master.getSend();saved=true}master.getOutputNode().disconnect();master.setSend(null)}else if(saved){master.getOutputNode().disconnect();master.setSend(prior)}};globalThis.MOBILE_PERF_NATIVE_BUS_INFO=function(){return GodotAudio.buses.map((b,i)=>({index:i,send_index:b.getSend()==null?-1:b.getSend().getId(),self_send:b.getSend()===b,gain:b._gainNode.gain.value,solo:b._soloNode.gain.value,mute:b._muteNode.gain.value}))}};'''
def patch_js(data):
 needle='set_sample_bus_send:function(busIndex,sendIndex){'
 assert data.count(needle)==1,'Official 4.7.2 sample bus source changed'
 return data.replace(needle,needle+HOOK)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--probe',type=Path,required=True);a=p.parse_args();out=a.probe
 template=Path('/workspace/toolchains/user-data/godot/export_templates/4.7.2.stable');records={}
 for kind,zipname,base in [('single','web_nothreads_debug.zip','index.d20938d2db49.engine'),('threaded','web_debug.zip','threaded')]:
  with ZipFile(template/zipname) as z:
   for name in ['godot.js','godot.wasm','godot.audio.worklet.js','godot.audio.position.worklet.js']:
    data=z.read(name);dest=out/name.replace('godot',base,1)
    if dest.is_symlink():dest.unlink()
    if name=='godot.js':data=patch_js(data.decode()).encode()
    if name=='godot.audio.worklet.js':data=(ROOT/'build/mobile_web_perf_01/worklet-instrumentation/diagnostic.audio.worklet.js').read_bytes()
    dest.write_bytes(data)
    records[kind+':'+name]={'official_sha256':hashlib.sha256(z.read(name)).hexdigest(),'diagnostic_sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
  html='''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no"><style>body{margin:0;background:black;overflow:hidden;touch-action:none}canvas{display:block;image-rendering:pixelated}</style><script src="audio_graph_probe.js"></script><script src="audio_probe.js"></script><script src="gpu_probe.js"></script></head><body><canvas id="canvas"></canvas><script src="'''+base+'''.js"></script><script>const engine=new Engine({canvasResizePolicy:2,executable:"'''+base+'''",mainPack:"diagnostic.pck",focusCanvas:true,ensureCrossOriginIsolationHeaders:false});engine.startGame({args:['--audio-output-latency',String(Number(new URLSearchParams(location.search).get('latency')||50))]}).then(()=>window.READY=true).catch(e=>console.error(e));</script></body></html>'''
  (out/('threaded.html' if kind=='threaded' else 'index.html')).write_text(html)
 for name in ['audio_graph_probe.js','audio_probe.js','pcm_worklet.js','gpu_probe.js']:shutil.copy2(ROOT/'tools/mobile_web_perf'/name,out/name)
 (out/'engine-variants.json').write_text(json.dumps({'scope':'official matched template/WASM; diagnostic control exposure and output-equivalent worklet counters only; original assets untouched','files':records},indent=2))
if __name__=='__main__':main()
