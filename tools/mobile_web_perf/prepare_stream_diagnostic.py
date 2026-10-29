"""Add opt-in Stream buffering comparison to an already verified standard bundle.

Same game pack and official JS/WASM, separately named counter-only worklet.
The normal index.html and official engine files are never modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True, type=Path)
    args = parser.parse_args()
    bundle = args.bundle
    info = json.loads((bundle/'build-info.json').read_text())
    original = 'index.' + info['engine_id'] + '.engine'
    target = 'audio-stream-diagnostic'
    files = {}
    for suffix in ('.js', '.wasm', '.audio.position.worklet.js'):
        source = bundle/(original+suffix)
        dest = bundle/(target+suffix)
        assert not dest.exists(), dest
        shutil.copyfile(source, dest)
        files[dest.name] = hashlib.sha256(dest.read_bytes()).hexdigest()
    worklet = bundle/(target+'.audio.worklet.js')
    result = subprocess.run([sys.executable, str(ROOT/'tools/mobile_web_perf/instrument_worklet.py'),
        str(bundle/(original+'.audio.worklet.js')), str(worklet), '--self-test'], capture_output=True, text=True, check=True)
    files[worklet.name] = hashlib.sha256(worklet.read_bytes()).hexdigest()
    for name in ('audio_probe.js', 'pcm_worklet.js'):
        shutil.copyfile(ROOT/'tools/mobile_web_perf'/name, bundle/name)
    html = (bundle/'index.html').read_text()
    match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', html)
    config = json.loads(match[1])
    config['executable'] = target
    config['fileSizes'][target+'.wasm'] = config['fileSizes'].pop(original+'.wasm')
    html = html[:match.start(1)] + json.dumps(config) + html[match.end(1):]
    html = html.replace('src="'+original+'.js"', 'src="'+target+'.js"')
    # Insert before engine construction; both cases use the same observer.
    html = html.replace('const engine = new Engine(GODOT_CONFIG);', '''
const audioLatency=Number(new URLSearchParams(location.search).get('latency')||50);
if (![50,200].includes(audioLatency)) throw Error('Only50/200ms diagnostic cases allowed');
GODOT_CONFIG.args=['--audio-output-latency',String(audioLatency)];
const engine = new Engine(GODOT_CONFIG);''')
    html = html.replace('</head>', '<script src="audio_probe.js"></script></head>')
    panel = '''<div id="audio-diagnostic-panel" style="position:fixed;left:4px;bottom:30px;z-index:100;color:#fff;background:#15222be8;padding:6px;font:12px sans-serif">
<span id="audio-case-label"></span><button id="audio-mark-game">记录游戏中</button><button id="audio-mark-menu">记录菜单中</button><button id="audio-save">下载检测记录</button></div>
<script>
window.AUDIO_STREAM_DIAGNOSTIC={version:1,latency_ms:audioLatency,build:BUILD_INFO,observations:[],scope:'Same standard PCK; counter-only diagnostic worklet. Browser audio ring underruns, not hardware speaker output.'};
document.getElementById('audio-case-label').textContent='音频检测 '+audioLatency+'ms ';
function audioSnapshot(phase){return {phase,at:performance.now(),audio:window.MOBILE_AUDIO_PROBE.snapshot(),ambience:window.SELECTED_AMBIENCE_SNAPSHOT||null,sfx:window.SELECTED_SFX_SNAPSHOT||null};}
async function audioRecord(phase){const row={phase,before:audioSnapshot(phase)};window.AUDIO_STREAM_DIAGNOSTIC.observations.push(row);document.getElementById('audio-case-label').textContent='记录中，请保持10秒 ';await new Promise(r=>setTimeout(r,10000));row.after=audioSnapshot(phase);document.getElementById('audio-case-label').textContent='已记录 '+phase+' · '+audioLatency+'ms ';}
document.getElementById('audio-mark-game').onclick=()=>audioRecord('game');
document.getElementById('audio-mark-menu').onclick=()=>audioRecord('menu');
document.getElementById('audio-save').onclick=()=>{const url=URL.createObjectURL(new Blob([JSON.stringify(window.AUDIO_STREAM_DIAGNOSTIC,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='audio-'+audioLatency+'ms.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
</script>'''.replace('BUILD_INFO', json.dumps(info))
    html = html.replace('</body>', panel+'</body>')
    (bundle/'audio-stream-test.html').write_text(html)
    (bundle/'audio-stream-diagnostic.json').write_text(json.dumps({'build_info':info,'latencies_ms':[50,200],
        'files_sha256':files,'worklet_instrumentation':result.stdout,'normal_entry_unchanged':True,
        'scope':'Diagnostic comparison only; not a confirmed fix or phone result'},indent=2)+'\n')


if __name__ == '__main__':
    main()
