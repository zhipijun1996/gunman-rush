"""Independent small loader fixtures; no engine/export/browser execution."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
from zipfile import ZipFile

ROOT = Path.cwd()
OUT = ROOT / 'build/mobile_web_audio_fix_03/review'
sys.path.insert(0, str(ROOT / 'tools'))
import build

with ZipFile('/workspace/toolchains/user-data/godot/export_templates/4.7.2.stable/web_debug.zip') as archive:
    template = archive.read('godot.html').decode()

results = []
for threaded in (False, True):
    folder = OUT / ('fixture-threaded' if threaded else 'fixture-single')
    folder.mkdir(exist_ok=True)
    pack = b'Reviewer byte fixture, not an actual exported game.'
    (folder / 'index.pck').write_bytes(pack)
    for name in ('index.js', 'index.wasm', 'index.audio.worklet.js', 'index.audio.position.worklet.js'):
        (folder / name).write_bytes(('Reviewer official-template loader fixture:' + name).encode())
    config = {'executable': 'index', 'mainPack': 'index.pck', 'args': [],
              'ensureCrossOriginIsolationHeaders': True, 'serviceWorker': '',
              'fileSizes': {'index.pck': len(pack), 'index.wasm': (folder / 'index.wasm').stat().st_size},
              'emscriptenPoolSize': 8, 'godotPoolSize': 4, 'gdextensionLibs': [],
              'canvasResizePolicy': 2, 'focusCanvas': True, 'experimentalVK': True}
    page = template
    values = {'$GODOT_PROJECT_NAME': 'Reviewer fixture', '$GODOT_SPLASH_COLOR': '#242424',
              '$GODOT_HEAD_INCLUDE': '', '$GODOT_SPLASH_CLASSES': 'show-image--false',
              '$GODOT_SPLASH': 'data:,', '$GODOT_URL': 'index.js',
              '$GODOT_CONFIG': json.dumps(config), '$GODOT_THREADS_ENABLED': str(threaded).lower()}
    for key, value in values.items():
        page = page.replace(key, value)
    html = folder / 'index.html'
    html.write_text(page)
    build.prepare_web_playtest(html)
    generated = html.read_text()
    info = json.loads((folder / 'build-info.json').read_text())
    assert info['threads_enabled'] is threaded
    assert info['audio_supply'] == ('dedicated_thread' if threaded else 'main_thread')
    assert info['build_id'] == hashlib.sha256(pack).hexdigest()[:12]
    cfg = json.loads(re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', generated)[1])
    assert cfg['emscriptenPoolSize'] == 8 and cfg['godotPoolSize'] == 4
    assert cfg['ensureCrossOriginIsolationHeaders'] is False
    assert cfg['args'] == []
    await_index = generated.index('await window.PLAYTEST_CACHE_READY;')
    assert await_index < generated.index('const missing = Engine.getMissingFeatures')
    assert generated.count('await window.PLAYTEST_CACHE_READY;') == 1
    assert '__THREADS_ENABLED__' not in generated
    for pattern in (r'<meta\b[^>]*name="viewport"[^>]*>', r'<canvas\b[^>]*>[\s\S]*?</canvas>'):
        assert re.findall(pattern, page) == re.findall(pattern, generated)
    inline = re.findall(r'<script\b[^>]*>([\s\S]*?)</script>', generated)
    bootstrap = next(value for value in inline if 'const GODOT_CONFIG' in value)
    for source in inline:
        check = subprocess.run(['node', '--check'], input=source, text=True, capture_output=True)
        assert check.returncode == 0, check.stderr
    (folder / 'bootstrap.js').write_text(bootstrap)
    results.append({'threaded': threaded, 'metadata': info, 'inline_syntax_checks': len(inline),
                    'feature_detection_after_cache_await': True, 'same_canvas_and_viewport': True})

script = r'''
const fs=require('fs'),vm=require('vm'),assert=require('assert');
const code=fs.readFileSync(process.argv[1],'utf8');
async function check(coi,cacheReady){let resolveReady;const trace=[],nodes=new Map();
 const get=id=>{if(!nodes.has(id))nodes.set(id,{style:{},lastChild:null,remove(){},removeAttribute(){},appendChild(v){trace.push(['notice',v])}});return nodes.get(id)};
 class Engine{constructor(config){trace.push(['constructor']);assert.equal(config.emscriptenPoolSize,8);assert.equal(config.godotPoolSize,4)}
  static getMissingFeatures(options){trace.push(['features']);assert.equal(options.threads,true);return coi?[]:['Cross-Origin Isolation missing'];}
  startGame(){trace.push(['start']);return Promise.resolve();}}
 const s={Engine,console,Promise,window:null,navigator:{serviceWorker:{}},
  document:{getElementById:get,createTextNode:value=>value,createElement:()=>({})}};
 s.window=s;s.PLAYTEST_CACHE_READY=new Promise(resolve=>resolveReady=resolve);vm.createContext(s);vm.runInContext(code,s);
 assert.deepEqual(trace,[['constructor']]);resolveReady(cacheReady);
 for(let i=0;i<20;i++)await Promise.resolve();
 assert.equal(trace.filter(v=>v[0]==='features').length,1);
 assert.equal(trace.filter(v=>v[0]==='start').length,coi?1:0);
 if(!coi)assert(trace.some(v=>v[0]==='notice'&&typeof v[1]==='string'&&v[1].includes('Cross-Origin Isolation')));
}
(async()=>{await check(true,true);await check(true,false);await check(false,false);
 console.log('PASS real generated bootstrap waits before feature check; actualCOI can use raw fallback; missingCOI fails visibly without start');})()
 .catch(e=>{console.error(e);process.exitCode=1});
'''
test = subprocess.run(['node', '--eval', script, str(OUT / 'fixture-threaded/bootstrap.js')],
                      text=True, capture_output=True)
assert test.returncode == 0, test.stdout + test.stderr
print(test.stdout, end='')
# Independently evaluate the two literal legacy link mappings with queries/hash.
for source, target, wanted in [
    ('https://example.test/game/audio-threaded/?latency=200&audio_probe=1#mark',
     '../audio-before/audio-threaded/',
     'https://example.test/game/audio-before/audio-threaded/?latency=200&audio_probe=1#mark'),
    ('https://example.test/game/audio-stream-test.html?latency=50&diag=timing-v1#mark',
     'audio-before/audio-stream-test.html',
     'https://example.test/game/audio-before/audio-stream-test.html?latency=50&diag=timing-v1#mark')]:
    check = subprocess.run(['node', '--eval',
        'const u=new URL(process.argv[1]);const out=new URL(process.argv[2]+u.search+u.hash,u).href;'
        'if(out!==process.argv[3])throw Error(out);', source, target, wanted], capture_output=True)
    assert check.returncode == 0, check.stderr
print('PASS both legacy diagnostic redirects preserve full query/hash and expected archived path')
(OUT / 'build-fixture-result.json').write_text(json.dumps({'passed': True, 'cases': results,
    'scope': 'Real official4.7.2HTML template and current production builder, tiny fake resource bytes. '
             'No valid PCK/WASM/runtime or engine/browser execution.'}, indent=2) + '\n')
print('PASS two real-template builder fixtures, inline syntax, metadata,8/4pools, unchanged viewport/canvas')
